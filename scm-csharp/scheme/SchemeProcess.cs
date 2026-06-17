using System;
using System.Diagnostics;
using System.IO;

namespace scheme;

public class SchemeProcess
{
    public Process process;

    // Windows-only: handle of the Job Object this process is assigned to, or
    // IntPtr.Zero if none (non-Windows, or job creation failed). process-kill
    // terminates the whole job, killing the entire descendant tree at once.
    public IntPtr jobHandle = IntPtr.Zero;

    // Parent-side writer for a 'log-file redirect, or null when no log file was
    // requested. start-program pumps the child's stdout/stderr into this writer
    // via async events, so the *supervisor* process holds the file open. It MUST
    // be released when the child is stopped: otherwise a restart — which opens
    // the log with FileMode.Create (truncate) — fails with a sharing violation
    // ("file used by another process"), even though the child itself is gone.
    // The Python original closed its log handle explicitly in stop_instance;
    // this mirrors that. Guarded so a late async callback after close is a no-op
    // rather than a write to a disposed stream.
    private StreamWriter? logWriter;
    private readonly object logLock = new object();
    private bool logClosed;

    public SchemeProcess(Process process) { this.process = process; }

    public void AttachLog(StreamWriter writer)
    {
        lock (logLock) { logWriter = writer; }
    }

    // Append one line; a no-op once the log has been closed.
    public void WriteLogLine(string line)
    {
        lock (logLock)
        {
            if (logClosed || logWriter == null) return;
            try { logWriter.WriteLine(line); } catch { /* tolerate write races */ }
        }
    }

    // Flush and release the log file handle. Idempotent; safe to call from the
    // Exited event, process-kill and process-wait.
    public void CloseLog()
    {
        lock (logLock)
        {
            if (logClosed) return;
            logClosed = true;
            try { logWriter?.Flush(); } catch { /* ignore */ }
            try { logWriter?.Dispose(); } catch { /* ignore */ }
            logWriter = null;
        }
    }

    public override string ToString() => $"#<process {process.Id}>";
}
