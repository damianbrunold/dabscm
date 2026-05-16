namespace scheme;

public class PrimitiveCommandLine : Primitive
{
    public override string Name() => "command-line";

    public override string Info() =>
        "Syntax: (command-line)\n" +
        "Library: (scheme process-context)\n" +
        "Description: Returns the command line passed to the process as a list of strings. The first element is the script name.\n" +
        "Example:\n" +
        "  (command-line) => (\"script.scm\" \"arg1\" \"arg2\")";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        var args = Scheme.CommandLineArgs;
        object result = Value.NIL;
        for (int i = args.Length - 1; i >= 0; i--)
            result = new Pair(args[i].ToCharArray(), result);
        return result;
    }
}
