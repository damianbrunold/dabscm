namespace scheme;

public class PrimitiveTextualPortP : Primitive
{
    public override string Name() => "textual-port?";
    public override string Info()
    {
        return
            "Syntax: (textual-port? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is a textual port (i.e., a port that reads or writes characters), #f otherwise.\n" +
            "Example:\n" +
            "  (textual-port? (current-input-port)) => #t\n" +
            "  (textual-port? (open-output-bytevector)) => #f";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return arguments[0] is TextStream || arguments[0] is TextWriter;
    }
}
