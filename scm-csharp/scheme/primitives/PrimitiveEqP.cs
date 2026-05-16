namespace scheme;

public class PrimitiveEqP : Primitive
{
    public override string Name()
    {
        return "eq?";
    }

    public override string Info()
    {
        return
            "Syntax: (eq? obj1 obj2)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj1 and obj2 are the same object. Equivalent to pointer equality for most types.\n" +
            "Example:\n" +
            "  (eq? 'a 'a) => #t\n" +
            "  (eq? '() '()) => #t\n" +
            "  (eq? (list 1) (list 1)) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        return Eq(arguments[0], arguments[1]);
    }

    public static bool Eq(object a, object b)
    {
        if (Value.IsBoolean(a) || Value.IsInteger(a))
        {
            return a.Equals(b);
        }
        return Object.ReferenceEquals(a, b);        
    }

}
