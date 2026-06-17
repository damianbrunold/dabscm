using System;
using System.Runtime.InteropServices;

namespace scheme;

// Wraps a Windows Job Object configured with JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE.
//
// Assigning a process to such a job means the *whole* descendant tree can be
// terminated atomically with TerminateJobObject — and any process the tree
// spawns later is automatically a member of the job too. This is immune to the
// reparenting / respawn races that defeat Process.Kill(entireProcessTree: true):
// e.g. a Flask dev server runs a reloader supervisor plus a worker grandchild,
// and the snapshot-based tree walk can miss the worker (leaving it holding the
// inherited stdout/stderr pipe open, so a parameterless WaitForExit never
// returns). A job has no such gap.
//
// Windows-only; callers must guard with RuntimeInformation.IsOSPlatform.
internal static class WindowsJobObject
{
    [StructLayout(LayoutKind.Sequential)]
    private struct JOBOBJECT_BASIC_LIMIT_INFORMATION
    {
        public long PerProcessUserTimeLimit;
        public long PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize;
        public UIntPtr MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint PriorityClass;
        public uint SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IO_COUNTERS
    {
        public ulong ReadOperationCount;
        public ulong WriteOperationCount;
        public ulong OtherOperationCount;
        public ulong ReadTransferCount;
        public ulong WriteTransferCount;
        public ulong OtherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION
    {
        public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
        public IO_COUNTERS IoInfo;
        public UIntPtr ProcessMemoryLimit;
        public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed;
        public UIntPtr PeakJobMemoryUsed;
    }

    private const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000;
    private const int JobObjectExtendedLimitInformation = 9;

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string? lpName);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetInformationJobObject(
        IntPtr hJob, int infoClass, IntPtr lpJobObjectInfo, uint cbJobObjectInfoLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AssignProcessToJobObject(IntPtr hJob, IntPtr hProcess);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateJobObject(IntPtr hJob, uint uExitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr hObject);

    // Create a kill-on-close job and assign processHandle to it. Returns the job
    // handle, or IntPtr.Zero on any failure (caller then falls back to the
    // Kill(entireProcessTree) path). Assigning right after Process.Start leaves a
    // microscopic window before the child can spawn anything, which is harmless
    // here since our children take real time to boot before forking workers.
    public static IntPtr CreateAndAssign(IntPtr processHandle)
    {
        IntPtr job = CreateJobObject(IntPtr.Zero, null);
        if (job == IntPtr.Zero) return IntPtr.Zero;

        var ext = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        ext.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

        int len = Marshal.SizeOf<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>();
        IntPtr ptr = Marshal.AllocHGlobal(len);
        try
        {
            Marshal.StructureToPtr(ext, ptr, false);
            if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, ptr, (uint) len)
                || !AssignProcessToJobObject(job, processHandle))
            {
                CloseHandle(job);
                return IntPtr.Zero;
            }
        }
        finally
        {
            Marshal.FreeHGlobal(ptr);
        }
        return job;
    }

    // Terminate every process in the job and release the handle. Safe to call
    // with IntPtr.Zero (no-op) and tolerant of an already-dead tree.
    public static void Terminate(IntPtr job)
    {
        if (job == IntPtr.Zero) return;
        try { TerminateJobObject(job, 1); } catch { /* already gone */ }
        try { CloseHandle(job); } catch { /* ignore */ }
    }
}
