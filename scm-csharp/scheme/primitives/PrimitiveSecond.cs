namespace scheme;

public class PrimitiveSecond : Primitive
{
    public override string Name()
    {
        return "second";
    }

    public override string Info()
    {
        return
            "Syntax: (second list)\n" +
            "Library: (srfi 1)\n" +
            "Description: Returns the second element of a list. Equivalent to (cadr list).\n" +
            "Example:\n" +
            "  (second '(a b c)) => b\n" +
            "  (second '(1 2 3)) => 2";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.AsPair(Value.AsPair(arguments[0]).cdr).car;
    }
}
