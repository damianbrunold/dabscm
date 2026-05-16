namespace scheme;

public class PrimitiveTerminalReadByte : Primitive
{
    public override string Name()
    {
        return "terminal-read-byte";
    }

    public override string Info()
    {
        return
            "Syntax: (terminal-read-byte)\n" +
            "Library: (scm terminal)\n" +
            "Description: Reads a single raw byte from standard input, bypassing\n" +
            "the port system and any line buffering. Returns an integer 0-255,\n" +
            "or an eof-object if the end of input has been reached.\n" +
            "Intended for use in raw terminal mode.\n" +
            "Example:\n" +
            "  (terminal-read-byte) => 27  ; ESC key";
    }

    private static Stream? rawStdin;

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        try
        {
            if (rawStdin == null)
                rawStdin = Console.OpenStandardInput();
            int b = rawStdin.ReadByte();
            if (b == -1)
                return Value.EOF;
            return b;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "terminal-read-byte: io failure: ~a", e.Message);
        }
    }
}
