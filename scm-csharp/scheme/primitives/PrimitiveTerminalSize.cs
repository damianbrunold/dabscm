namespace scheme;

public class PrimitiveTerminalSize : Primitive
{
    public override string Name()
    {
        return "terminal-size";
    }

    public override string Info()
    {
        return
            "Syntax: (terminal-size)\n" +
            "Library: (scm terminal)\n" +
            "Description: Returns the terminal dimensions as a pair (cols . rows),\n" +
            "or #f if the terminal size cannot be determined.\n" +
            "Example:\n" +
            "  (terminal-size) => (80 . 24)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        try
        {
            if (Console.IsOutputRedirected && Console.IsInputRedirected)
                return (object)false;
            int cols = Console.WindowWidth;
            int rows = Console.WindowHeight;
            if (cols <= 0 || rows <= 0)
                return (object)false;
            return new Pair(cols, rows);
        }
        catch
        {
            return (object)false;
        }
    }
}
