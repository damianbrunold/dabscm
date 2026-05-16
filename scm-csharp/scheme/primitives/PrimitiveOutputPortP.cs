namespace scheme;

public class PrimitiveOutputPortP : Primitive
{
    public override string Name()
    {
        return "output-port?";
    }

    public override string Info()
    {
        return
            "Syntax: (output-port? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is an output port, otherwise returns #f.\n" +
            "Example:\n" +
            "  (output-port? (open-output-string)) => #t\n" +
            "  (output-port? (current-output-port)) => #t\n" +
            "  (output-port? 42) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsOutputPort(arguments[0]);
    }
}
