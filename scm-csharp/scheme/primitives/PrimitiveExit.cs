namespace scheme;

public class PrimitiveExit : Primitive
{
    public override string Name()
    {
        return "exit";
    }

    public override string Info()
    {
        return
            "Syntax: (exit) (exit obj)\n" +
            "Library: (scheme process-context)\n" +
            "Description: Terminates the current program. If obj is an exact integer, it is used as the exit code. Without an argument, exits with code 1.\n" +
            "Example:\n" +
            "  (exit)\n" +
            "  (exit 0)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);
        if (arguments.Length == 0)
        {
            Environment.Exit(1);
        }
        else
        {
            Environment.Exit(IntegerMath.ToInt(arguments[0]));
        }
        return new Values();
    }
}
