namespace scheme;

public class PrimitiveBitwiseAnd : Primitive
{
    public override string Name()
    {
        return "bitwise-and";
    }

    public override string Info()
    {
        return
            "Syntax: (bitwise-and i ...)\n" +
            "Library: (srfi 151)\n" +
            "Description: Returns the bitwise AND of its arguments. With no arguments,\n" +
            "returns -1 (all bits set).\n" +
            "Example:\n" +
            "  (bitwise-and 14 10) => 10\n" +
            "  (bitwise-and 14 10 12) => 8\n" +
            "  (bitwise-and) => -1";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        if (arguments.Length == 0) return -1L;
        object result = arguments[0];
        for (int i = 1; i < arguments.Length; i++)
        {
            result = IntegerMath.BitwiseAnd(result, arguments[i]);
        }
        return result;
    }
}
