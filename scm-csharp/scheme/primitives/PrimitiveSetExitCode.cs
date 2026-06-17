namespace scheme;

public class PrimitiveSetExitCode : Primitive
{
    public override string Name()
    {
        return "set-exit-code!";
    }

    public override string Info()
    {
        return
            "Syntax: (set-exit-code! code)\n" +
            "Library: (scheme process-context)\n" +
            "Description: Records the exit code the process should return when the\n" +
            "  current script finishes, without terminating immediately (unlike exit).\n" +
            "  The standalone script runner honours this after the script completes.\n" +
            "  code must be an exact integer. Returns an unspecified value.\n" +
            "Example:\n" +
            "  (set-exit-code! 1)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        Scheme.PendingExitCode = IntegerMath.ToInt(arguments[0]);
        return new Values();
    }
}
