using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

namespace scheme;

public class PrimitiveStartProgram : Primitive
{
    public override string Name() => "start-program";

    public override string Info() =>
        "Syntax: (start-program cmd-and-args [options])\n" +
        "Library: (scm system)\n" +
        "Description: Starts an external program without waiting for it to finish " +
        "and returns a process handle (a native value). cmd-and-args is a list " +
        "(program arg1 arg2 ...). options is an alist with optional keys: " +
        "'work-dir <path>, 'log-file <path> (redirects stdout+stderr to this file), " +
        "'env <alist of (name value) string pairs added to the child environment>. " +
        "Use process-pid, process-kill, process-wait, process-alive? on the handle.\n" +
        "Example:\n" +
        "  (define p (start-program '(\"sleep\" \"30\")))\n" +
        "  (process-kill p)\n" +
        "  (process-wait p)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        Pair cmdline = Value.AsPair(arguments[0]);
        object options = arguments.Length > 1 ? arguments[1] : Value.NIL;

        string cmd = new String(Value.AsString(cmdline.car));
        var args = new System.Collections.Generic.List<string>();
        object p = cmdline.cdr;
        while (p != Value.NIL)
        {
            var pp = Value.AsPair(p);
            args.Add(new String(Value.AsString(pp.car)));
            p = pp.cdr;
        }

        try
        {
            var psi = new ProcessStartInfo(cmd, args);
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;

            string? logfile = null;
            if (options != Value.NIL)
            {
                var workdirVal = PrimitiveGetProperty.GetProperty(options, "work-dir", Value.F);
                if (!workdirVal.Equals(Value.F))
                    psi.WorkingDirectory = new String(Value.AsString(workdirVal));

                var logfileVal = PrimitiveGetProperty.GetProperty(options, "log-file", Value.F);
                if (!logfileVal.Equals(Value.F))
                {
                    logfile = new String(Value.AsString(logfileVal));
                    psi.RedirectStandardOutput = true;
                    psi.RedirectStandardError = true;
                }

                ProcessEnvUtil.Apply(psi, options);
            }

            var proc = new Process();
            proc.StartInfo = psi;

            var sp = new SchemeProcess(proc);

            if (logfile != null)
            {
                var writer = new StreamWriter(
                    new FileStream(logfile, FileMode.Create, FileAccess.Write, FileShare.Read))
                    { AutoFlush = true };
                sp.AttachLog(writer);
                proc.OutputDataReceived += (s, e) => { if (e.Data != null) sp.WriteLogLine(e.Data); };
                proc.ErrorDataReceived  += (s, e) => { if (e.Data != null) sp.WriteLogLine(e.Data); };
                // Release the log handle if the child exits on its own (crash or
                // self-stop), so the supervisor never keeps the file open behind
                // an instance it no longer tracks. process-kill / process-wait
                // close it on the explicit-stop path; this covers the rest.
                proc.EnableRaisingEvents = true;
                proc.Exited += (s, e) => sp.CloseLog();
            }

            proc.Start();

            if (logfile != null)
            {
                proc.BeginOutputReadLine();
                proc.BeginErrorReadLine();
            }

            // On Windows, contain the whole descendant tree in a kill-on-close
            // Job Object so process-kill can take it down atomically (the
            // entireProcessTree walk otherwise misses reloader grandchildren).
            // On failure jobHandle stays Zero and process-kill falls back.
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                try { sp.jobHandle = WindowsJobObject.CreateAndAssign(proc.Handle); }
                catch { /* fall back to Kill(entireProcessTree) on stop */ }
            }

            return new NativeValue(sp);
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "start-program: " + e.Message);
        }
    }
}
