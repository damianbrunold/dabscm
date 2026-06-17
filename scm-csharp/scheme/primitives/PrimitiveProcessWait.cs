namespace scheme;

public class PrimitiveProcessWait : Primitive
{
    public override string Name() => "process-wait";

    public override string Info() =>
        "Syntax: (process-wait handle [timeout-ms])\n" +
        "Library: (scm system)\n" +
        "Description: Waits for the process to exit. Without timeout-ms, blocks " +
        "until exit and returns the exit code as an integer. With timeout-ms, " +
        "waits at most that long; returns the exit code on exit, or #f if the " +
        "process is still running when the timeout elapses.\n" +
        "Example:\n" +
        "  (process-wait p)            => 0\n" +
        "  (process-wait p 5000)       => 0 or #f";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        SchemeProcess sp = (SchemeProcess) Value.AsNativeValue(arguments[0]).value;
        if (arguments.Length == 1)
        {
            // Parameterless WaitForExit also drains the async output handlers, so
            // the log is fully written before we release it.
            sp.process.WaitForExit();
            sp.CloseLog();
            return (long) sp.process.ExitCode;
        }
        int timeoutMs = IntegerMath.ToInt(arguments[1]);
        if (sp.process.WaitForExit(timeoutMs))
        {
            sp.CloseLog();
            return (long) sp.process.ExitCode;
        }
        return Value.F;
    }
}
