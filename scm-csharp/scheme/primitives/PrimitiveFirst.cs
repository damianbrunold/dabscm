namespace scheme;

public class PrimitiveFirst : Primitive
{
    public override string Name()
    {
        return "first";
    }

    public override string Info()
    {
        return
            "Syntax: (first lst)\n" +
            "Library: (srfi 1)\n" +
            "Description: Returns the first element of list lst. Equivalent to car.\n" +
            "Example:\n" +
            "  (first '(a b c)) => a";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.AsPair(arguments[0]).car;
    }
}
