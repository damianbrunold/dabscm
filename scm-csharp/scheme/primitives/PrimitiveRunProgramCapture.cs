using System.Diagnostics;
using System.Text;

namespace scheme;

public class PrimitiveRunProgramCapture : Primitive
{
    public override string Name() => "run-program/capture";

    public override string Info() =>
        "Syntax: (run-program/capture cmd [options])\n" +
        "Library: (scm system)\n" +
        "Description: Executes the external program specified as a list " +
        "(program arg1 arg2 ...), waits for it to complete, and returns a list " +
        "(exit-code stdout stderr) where stdout and stderr are captured as strings. " +
        "options is an alist with optional keys: 'work-dir <path>, 'stdin <string> " +
        "(text to write to the child's standard input), 'env <alist of (name value) " +
        "string pairs added to the child environment>. Returns #f on failure.\n" +
        "Example:\n" +
        "  (run-program/capture '(\"echo\" \"hello\")) => (0 \"hello\\n\" \"\")";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        Pair cmdline = Value.AsPair(arguments[0]);
        object options = arguments.Length > 1 ? arguments[1] : Value.NIL;

        try
        {
            string cmd = new String(Value.AsString(cmdline.car));
            var args = new List<string>();
            object p = cmdline.cdr;
            while (p != Value.NIL)
            {
                var pp = Value.AsPair(p);
                args.Add(new String(Value.AsString(pp.car)));
                p = pp.cdr;
            }

            var psi = ProcUtil.CreateStartInfo(cmd, args);
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;

            string? stdinText = null;
            if (options != Value.NIL)
            {
                var workdirVal = PrimitiveGetProperty.GetProperty(options, "work-dir", Value.F);
                if (!workdirVal.Equals(Value.F))
                    psi.WorkingDirectory = new String(Value.AsString(workdirVal));

                var stdinVal = PrimitiveGetProperty.GetProperty(options, "stdin", Value.F);
                if (!stdinVal.Equals(Value.F))
                {
                    stdinText = new String(Value.AsString(stdinVal));
                    psi.RedirectStandardInput = true;
                }

                ProcessEnvUtil.Apply(psi, options);
            }

            var process = new Process();
            process.StartInfo = psi;

            process.Start();
            // the output as it is, read to the end on both pipes at once (no
            // deadlock when one fills up); line-by-line reading would turn
            // CRLF into LF and add a newline the program did not write
            var stdoutTask = process.StandardOutput.ReadToEndAsync();
            var stderrTask = process.StandardError.ReadToEndAsync();

            if (stdinText != null)
            {
                process.StandardInput.Write(stdinText);
                process.StandardInput.Close();
            }

            string stdoutText = stdoutTask.GetAwaiter().GetResult();
            string stderrText = stderrTask.GetAwaiter().GetResult();
            process.WaitForExit();

            object result = Value.NIL;
            result = new Pair(stderrText.ToCharArray(), result);
            result = new Pair(stdoutText.ToCharArray(), result);
            result = new Pair((long) process.ExitCode, result);
            return result;
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
