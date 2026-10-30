using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

namespace scheme;

// Kills a process together with all of its descendants on Windows.
//
// Mirrors the Java ProcessUtil.destroyTree (and the Python original's psutil
// kill_proc_tree): snapshot the descendant tree *while the root is still
// alive*, then TerminateProcess every member. The Job Object start-program
// creates is terminated as well, but it is only a bonus: it is assigned after
// Process.Start, so a child the root spawns before the assignment (e.g. the
// python a venv flask.exe launcher starts) is not in it. Terminating the job
// first and walking the tree afterwards — as process-kill used to — found the
// root already dead, so Kill(entireProcessTree) bailed out and such children
// survived, holding the inherited stdout/stderr pipe open forever.
//
// Windows-only; callers must guard with RuntimeInformation.IsOSPlatform.
internal static class WindowsProcessTree
{
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

    private const uint TH32CS_SNAPPROCESS = 0x2;
    private static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr CreateToolhelp32Snapshot(uint dwFlags, uint th32ProcessID);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool Process32FirstW(IntPtr hSnapshot, ref PROCESSENTRY32W lppe);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool Process32NextW(IntPtr hSnapshot, ref PROCESSENTRY32W lppe);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr hObject);

    // Kill root and its whole descendant tree, and terminate job (may be Zero).
    public static void Kill(Process root, IntPtr job)
    {
        // pid -> start time of every tree member seen so far. The start time
        // guards against pid reuse: a process only counts as a child if it was
        // created after its supposed parent.
        var known = new Dictionary<int, DateTime>();
        known[root.Id] = StartTimeOf(root) ?? DateTime.MinValue;

        // Snapshot first, while the root is alive and the links are intact.
        var victims = CollectNew(known);

        // Top-down: a killed parent cannot respawn the child we kill next.
        try { root.Kill(); } catch { /* already exited */ }
        KillAll(victims, known);
        WindowsJobObject.Terminate(job);

        // Sweep again for children spawned by a member between the snapshot
        // and its death (e.g. a reloader restarting its worker). Their parent
        // pid still names the dead member, so the walk finds them.
        for (int round = 0; round < 3; round++)
        {
            Thread.Sleep(50);
            victims = CollectNew(known);
            if (victims.Count == 0) break;
            KillAll(victims, known);
        }
    }

    // Breadth-first walk from the known pids; adds and returns the new ones.
    private static List<int> CollectNew(Dictionary<int, DateTime> known)
    {
        var found = new List<int>();
        var links = Snapshot();
        bool grew = true;
        while (grew)
        {
            grew = false;
            foreach (var (pid, ppid) in links)
            {
                if (known.ContainsKey(pid) || !known.TryGetValue(ppid, out var parentStart))
                    continue;
                DateTime? start = StartTimeOf(pid);
                if (start == null || start.Value < parentStart) continue;
                known[pid] = start.Value;
                found.Add(pid);
                grew = true;
            }
        }
        return found;
    }

    private static void KillAll(List<int> pids, Dictionary<int, DateTime> known)
    {
        foreach (int pid in pids)
        {
            try
            {
                using var p = Process.GetProcessById(pid);
                if (p.StartTime == known[pid]) p.Kill();
            }
            catch { /* already exited or not accessible */ }
        }
    }

    private static List<(int pid, int ppid)> Snapshot()
    {
        var result = new List<(int, int)>();
        IntPtr snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if (snap == INVALID_HANDLE_VALUE) return result;
        try
        {
            var entry = new PROCESSENTRY32W { dwSize = (uint) Marshal.SizeOf<PROCESSENTRY32W>() };
            for (bool ok = Process32FirstW(snap, ref entry); ok; ok = Process32NextW(snap, ref entry))
                result.Add(((int) entry.th32ProcessID, (int) entry.th32ParentProcessID));
        }
        finally
        {
            CloseHandle(snap);
        }
        return result;
    }

    private static DateTime? StartTimeOf(Process p)
    {
        try { return p.StartTime; } catch { return null; }
    }

    private static DateTime? StartTimeOf(int pid)
    {
        try
        {
            using var p = Process.GetProcessById(pid);
            return p.StartTime;
        }
        catch { return null; }
    }
}
