using System;
using System.Collections.Generic;
using System.IO;
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
}
