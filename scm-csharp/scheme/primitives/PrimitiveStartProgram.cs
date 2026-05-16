using System;
using System.Diagnostics;
using System.IO;

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
        "'work-dir <path>, 'log-file <path> (redirects stdout+stderr to this file). " +
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
            }

            var proc = new Process();
            proc.StartInfo = psi;

            if (logfile != null)
            {
                var writer = new StreamWriter(
                    new FileStream(logfile, FileMode.Create, FileAccess.Write, FileShare.Read))
                    { AutoFlush = true };
                proc.OutputDataReceived += (s, e) => { if (e.Data != null) writer.WriteLine(e.Data); };
                proc.ErrorDataReceived  += (s, e) => { if (e.Data != null) writer.WriteLine(e.Data); };
            }

            proc.Start();

            if (logfile != null)
            {
                proc.BeginOutputReadLine();
                proc.BeginErrorReadLine();
            }

            return new NativeValue(new SchemeProcess(proc));
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "start-program: " + e.Message);
        }
    }
}
