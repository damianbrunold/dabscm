namespace scheme;

public class PrimitiveBitwiseIor : Primitive
{
    public override string Name()
    {
        return "bitwise-ior";
    }

    public override string Info()
    {
        return
            "Syntax: (bitwise-ior i ...)\n" +
            "Library: (srfi 151)\n" +
            "Description: Returns the bitwise inclusive OR of its arguments. With no\n" +
            "arguments, returns 0.\n" +
            "Example:\n" +
            "  (bitwise-ior 10 12) => 14\n" +
            "  (bitwise-ior) => 0";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        if (arguments.Length == 0) return 0L;
        object result = arguments[0];
        for (int i = 1; i < arguments.Length; i++)
        {
            result = IntegerMath.BitwiseIor(result, arguments[i]);
        }
        return result;
    }
}
