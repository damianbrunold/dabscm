namespace scheme;

public class PrimitiveBooleanP : Primitive
{
    public override string Name()
    {
        return "boolean?";
    }

    public override string Info()
    {
        return
            "Syntax: (boolean? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is either #t or #f, otherwise returns #f.\n" +
            "Example:\n" +
            "  (boolean? #f) => #t\n" +
            "  (boolean? 0) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsBoolean(arguments[0]);
    }
}
