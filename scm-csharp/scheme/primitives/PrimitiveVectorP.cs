namespace scheme;

public class PrimitiveVectorP : Primitive
{
    public override string Name()
    {
        return "vector?";
    }

    public override string Info()
    {
        return
            "Syntax: (vector? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is a vector, #f otherwise.\n" +
            "Example:\n" +
            "  (vector? #(1 2 3)) => #t\n" +
            "  (vector? '(1 2 3)) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsVector(arguments[0]);
    }
}
