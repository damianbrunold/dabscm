using System;
using System.IO;

namespace scheme;

internal static class ProcUtil
{
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
