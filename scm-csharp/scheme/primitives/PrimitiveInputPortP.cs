namespace scheme;

public class PrimitiveInputPortP : Primitive
{
    public override string Name()
    {
        return "input-port?";
    }

    public override string Info()
    {
        return
            "Syntax: (input-port? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is an input port, otherwise returns #f.\n" +
            "Example:\n" +
            "  (input-port? (open-input-string \"abc\")) => #t\n" +
            "  (input-port? (open-output-string)) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsInputPort(arguments[0]);
    }
}
