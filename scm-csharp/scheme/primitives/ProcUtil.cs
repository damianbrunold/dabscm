using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;

namespace scheme;

internal static class ProcUtil
{
    // --- Windows parent-pid lookup ------------------------------------------
    // .NET's managed Process class exposes no parent pid, so on Windows we take
    // one toolhelp snapshot of every process and read th32ParentProcessID. This
    // uses only kernel32 (a system DLL — no package dependency). The result is a
    // whole-system pid -> ppid map, built once per (ps) call rather than per pid.

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct PROCESSENTRY32W
    {
        public uint dwSize;
        public uint cntUsage;
        public uint th32ProcessID;
        public IntPtr th32DefaultHeapID;
        public uint th32ModuleID;
        public uint cntThreads;
        public uint th32ParentProcessID;
        public int pcPriClassBase;
        public uint dwFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string szExeFile;
    }

    private const uint TH32CS_SNAPPROCESS = 0x00000002;
    private static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr CreateToolhelp32Snapshot(uint dwFlags, uint th32ProcessID);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool Process32FirstW(IntPtr hSnapshot, ref PROCESSENTRY32W lppe);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool Process32NextW(IntPtr hSnapshot, ref PROCESSENTRY32W lppe);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr hObject);

    // Snapshot every process and return a pid -> ppid map. Empty on failure.
    // Only meaningful on Windows; never called on other platforms.
    public static Dictionary<int, int> WindowsPpidMap()
    {
        var map = new Dictionary<int, int>();
        IntPtr snap = INVALID_HANDLE_VALUE;
        try
        {
            snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
            if (snap == INVALID_HANDLE_VALUE) return map;
            var entry = new PROCESSENTRY32W { dwSize = (uint) Marshal.SizeOf<PROCESSENTRY32W>() };
            if (Process32FirstW(snap, ref entry))
            {
                do { map[(int) entry.th32ProcessID] = (int) entry.th32ParentProcessID; }
                while (Process32NextW(snap, ref entry));
            }
        }
        catch (Exception) { /* fall back to an empty map -> ppid stays #f */ }
        finally { if (snap != INVALID_HANDLE_VALUE) CloseHandle(snap); }
        return map;
    }

    // Parse /proc/<pid>/stat and return the parent pid (4th field), tolerating
    // spaces or parens inside the second "comm" field (which is wrapped in
    // parens).
    public static long? ReadPpid(string pidStr)
    {
        try
        {
            string s = File.ReadAllText("/proc/" + pidStr + "/stat");
            int close = s.LastIndexOf(')');
            if (close < 0 || close + 2 >= s.Length) return null;
            // After ')': " <state> <ppid> ..."
            string rest = s.Substring(close + 1).TrimStart();
            string[] parts = rest.Split(' ');
            if (parts.Length < 2) return null;
            if (long.TryParse(parts[1], out long ppid)) return ppid;
            return null;
        }
        catch (Exception) { return null; }
    }

    // Read the full command line from /proc/<pid>/cmdline (NUL-separated args).
    public static string? ReadCmdline(string pidStr)
    {
        try
        {
            byte[] bytes = File.ReadAllBytes("/proc/" + pidStr + "/cmdline");
            if (bytes.Length == 0) return null;
            // Replace NULs with spaces; strip a trailing NUL.
            int end = bytes.Length;
            while (end > 0 && bytes[end - 1] == 0) end--;
            var chars = new char[end];
            for (int i = 0; i < end; i++) chars[i] = bytes[i] == 0 ? ' ' : (char) bytes[i];
            return new string(chars);
        }
        catch (Exception) { return null; }
    }

    // Read the "Uid:" line from /proc/<pid>/status and return the real uid.
    public static long? ReadUid(string pidStr)
    {
        try
        {
            foreach (string line in File.ReadAllLines("/proc/" + pidStr + "/status"))
            {
                if (line.StartsWith("Uid:"))
                {
                    string[] parts = line.Substring(4).Trim().Split('\t', ' ');
                    foreach (string p in parts)
                    {
                        if (p.Length == 0) continue;
                        if (long.TryParse(p, out long uid)) return uid;
                        break;
                    }
                }
            }
            return null;
        }
        catch (Exception) { return null; }
    }

    // --- launching .bat/.cmd scripts on Windows -----------------------------
    // With UseShellExecute = false, .NET hands the program to CreateProcess,
    // which only appends ".exe" to a name without an extension, so a "scm"
    // that is really scm.bat on PATH is not found. run-program,
    // run-program/capture and start-program therefore build their
    // ProcessStartInfo here: on Windows, a program that resolves (via PATH and
    // PATHEXT, honouring extension precedence so a .exe still wins) to a
    // .bat/.cmd script is run through cmd.exe, as the Java implementation's
    // ProcessUtil.resolveBatchLauncher does. Everything else is unchanged.
    //
    // The command line is `cmd.exe /d /s /c "<quoted script> <quoted args>"`:
    // /s makes cmd strip exactly the outer quotes, so paths and arguments with
    // spaces survive; /d skips AutoRun commands.
    public static ProcessStartInfo CreateStartInfo(string cmd, List<string> args)
    {
        string? batch = OperatingSystem.IsWindows() ? ResolveBatch(cmd) : null;
        if (batch == null) return new ProcessStartInfo(cmd, args);
        var sb = new StringBuilder("/d /s /c \"");
        sb.Append(QuoteArg(batch));
        foreach (var a in args)
        {
            sb.Append(' ');
            sb.Append(QuoteArg(a));
        }
        sb.Append('"');
        return new ProcessStartInfo("cmd.exe", sb.ToString());
    }

    // The full path of prog iff it resolves to a .bat/.cmd file, else null.
    private static string? ResolveBatch(string prog)
    {
        if (IsBatch(Path.GetExtension(prog))) return FindOnPath(prog) ?? prog;
        if (Path.HasExtension(prog)) return null; // e.g. .exe: leave it alone

        var exts = PathExt();
        if (HasPathSeparator(prog))
        {
            foreach (var ext in exts)
                if (File.Exists(prog + ext))
                    return IsBatch(ext) ? Path.GetFullPath(prog + ext) : null;
            return null;
        }
        var path = Environment.GetEnvironmentVariable("PATH");
        if (path == null) return null;
        foreach (var dir in path.Split(Path.PathSeparator))
        {
            if (dir.Length == 0) continue;
            foreach (var ext in exts)
            {
                var f = Path.Combine(dir, prog + ext);
                if (File.Exists(f)) return IsBatch(ext) ? f : null;
            }
        }
        return null;
    }

    private static string? FindOnPath(string prog)
    {
        if (File.Exists(prog)) return Path.GetFullPath(prog);
        if (HasPathSeparator(prog)) return null;
        var path = Environment.GetEnvironmentVariable("PATH");
        if (path == null) return null;
        foreach (var dir in path.Split(Path.PathSeparator))
        {
            if (dir.Length == 0) continue;
            var f = Path.Combine(dir, prog);
            if (File.Exists(f)) return f;
        }
        return null;
    }

    private static List<string> PathExt()
    {
        var pe = Environment.GetEnvironmentVariable("PATHEXT");
        if (string.IsNullOrEmpty(pe)) pe = ".COM;.EXE;.BAT;.CMD";
        var exts = new List<string>();
        foreach (var e in pe.Split(';'))
        {
            var t = e.Trim();
            if (t.Length > 0) exts.Add(t);
        }
        return exts;
    }

    private static bool IsBatch(string ext) =>
        ext.Equals(".bat", StringComparison.OrdinalIgnoreCase)
        || ext.Equals(".cmd", StringComparison.OrdinalIgnoreCase);

    private static bool HasPathSeparator(string prog) =>
        prog.IndexOf('\\') >= 0 || prog.IndexOf('/') >= 0;

    // Quote one argument by the MSVC runtime rules (as ProcessStartInfo's
    // ArgumentList does): wrap in quotes when it is empty or contains
    // whitespace or a quote; double the backslashes before a quote.
    private static string QuoteArg(string a)
    {
        if (a.Length > 0 && a.IndexOfAny(new[] { ' ', '\t', '\n', '\v', '"' }) < 0)
            return a;
        var sb = new StringBuilder("\"");
        int backslashes = 0;
        foreach (var c in a)
        {
            if (c == '\\') { backslashes++; continue; }
            if (c == '"') sb.Append('\\', backslashes * 2 + 1);
            else sb.Append('\\', backslashes);
            backslashes = 0;
            sb.Append(c);
        }
        sb.Append('\\', backslashes * 2);
        sb.Append('"');
        return sb.ToString();
    }
}
