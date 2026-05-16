namespace scheme;

public class PrimitiveVectorSetB : Primitive
{
    public override string Name()
    {
        return "vector-set!";
    }

    public override string Info()
    {
        return
            "Syntax: (vector-set! v k obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Stores obj in element k of vector v. It is an error if k is not a valid index of v.\n" +
            "Example:\n" +
            "  (let ((v (vector 1 2 3))) (vector-set! v 1 99) v) => #(1 99 3)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        Value.AsVector(arguments[0])[(int) (long) arguments[1]] = arguments[2];
        return new Values();
    }
}
