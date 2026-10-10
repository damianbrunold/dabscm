namespace scheme;

public class PrimitiveVectorRef : Primitive
{
    public override string Name()
    {
        return "vector-ref";
    }

    public override string Info()
    {
        return
            "Syntax: (vector-ref v k)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the element at index k in vector v. If k is out of range and a default is provided, returns the default instead of signalling an error.\n" +
            "Example:\n" +
            "  (vector-ref #(a b c) 1) => b\n" +
            "  (vector-ref #(a b c) 5 'none) => none";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        var v = Value.AsVector(arguments[0]);
        var idx = IntegerMath.ToInt(arguments[1]);
        if (idx < 0 || idx >= v.Length)
        {
            if (arguments.Length == 3) return arguments[2];
            throw new SchemeError(pos, "vector-ref: index out of range: ~a", arguments[1]);
        }
        return v[idx];
    }
}
