namespace scheme;

public class PrimitiveTerminalP : Primitive
{
    public override string Name()
    {
        return "terminal?";
    }

    public override string Info()
    {
        return
            "Syntax: (terminal?)\n" +
            "Syntax: (terminal? which)\n" +
            "Library: (scm terminal)\n" +
            "Description: Returns #t if the process is connected to a terminal.\n" +
            "If which is 'input, checks only the input stream.\n" +
            "If which is 'output, checks only the output stream.\n" +
            "With no arguments, returns #t only if both input and output are terminals.\n" +
            "Example:\n" +
            "  (terminal?) => #t";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);
        if (arguments.Length == 1)
        {
            string which = Value.AsSymbol(arguments[0]);
            if (which == "input")
                return (object)!Console.IsInputRedirected;
            else if (which == "output")
                return (object)!Console.IsOutputRedirected;
            else
                throw new SchemeError(pos, "terminal?: expected 'input or 'output, got ~s", Value.PrintRep(arguments[0]));
        }
        return (object)(!Console.IsInputRedirected && !Console.IsOutputRedirected);
    }
}
