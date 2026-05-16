namespace scheme;

public class PrimitiveVectorLength : Primitive
{
    public override string Name()
    {
        return "vector-length";
    }

    public override string Info()
    {
        return
            "Syntax: (vector-length v)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the number of elements in vector v.\n" +
            "Example:\n" +
            "  (vector-length #(1 2 3)) => 3\n" +
            "  (vector-length (vector)) => 0";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return (long) Value.AsVector(arguments[0]).Length;
    }
}
