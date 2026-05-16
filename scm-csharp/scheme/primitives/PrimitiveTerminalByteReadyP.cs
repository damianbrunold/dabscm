namespace scheme;

public class PrimitiveTerminalByteReadyP : Primitive
{
    public override string Name()
    {
        return "terminal-byte-ready?";
    }

    public override string Info()
    {
        return
            "Syntax: (terminal-byte-ready?)\n" +
            "Library: (scm terminal)\n" +
            "Description: Returns #t if a byte is available for reading from\n" +
            "standard input without blocking, #f otherwise.\n" +
            "Intended for use in raw terminal mode to detect multi-byte\n" +
            "escape sequences.\n" +
            "Example:\n" +
            "  (terminal-byte-ready?) => #f";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        try
        {
            if (!Console.IsInputRedirected)
                return (object)Console.KeyAvailable;
            return (object)(Console.In.Peek() != -1);
        }
        catch
        {
            return (object)false;
        }
    }
}
