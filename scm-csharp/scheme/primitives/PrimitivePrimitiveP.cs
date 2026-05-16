namespace scheme;

public class PrimitivePrimitiveP : Primitive
{
    public override string Name()
    {
        return "primitive?";
    }

    public override string Info()
    {
        return
            "Syntax: (primitive? obj)\n" +
            "Library: (scm core)\n" +
            "Description: Returns #t if obj is a built-in primitive procedure, otherwise returns #f.\n" +
            "Example:\n" +
            "  (primitive? car) => #t\n" +
            "  (primitive? (lambda (x) x)) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsPrimitive(arguments[0]);
    }
}
