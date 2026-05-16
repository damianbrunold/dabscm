namespace scheme;

public class PrimitiveBitwiseXor : Primitive
{
    public override string Name()
    {
        return "bitwise-xor";
    }

    public override string Info()
    {
        return
            "Syntax: (bitwise-xor i ...)\n" +
            "Library: (srfi 151)\n" +
            "Description: Returns the bitwise exclusive OR of its arguments. With no\n" +
            "arguments, returns 0.\n" +
            "Example:\n" +
            "  (bitwise-xor 10 12) => 6\n" +
            "  (bitwise-xor) => 0";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        if (arguments.Length == 0) return 0L;
        object result = arguments[0];
        for (int i = 1; i < arguments.Length; i++)
        {
            result = IntegerMath.BitwiseXor(result, arguments[i]);
        }
        return result;
    }
}
