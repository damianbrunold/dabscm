using System.Numerics;

namespace scheme;

public class PrimitiveNumberToString : Primitive
{
    public override string Name()
    {
        return "number->string";
    }

    public override string Info()
    {
        return
            "Syntax: (number->string z) (number->string z radix)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns a string representation of z in the given radix (default 10). Exact integers support any radix.\n" +
            "Example:\n" +
            "  (number->string 42) => \"42\"\n" +
            "  (number->string 255 16) => \"ff\"\n" +
            "  (number->string 3.14) => \"3.14\"";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        if (Value.IsComplex(arguments[0]))
        {
            return Value.AsComplex(arguments[0]).ToString().ToCharArray();
        }
        // Fast path: single integer argument (most common case)
        if (arguments[0] is long n && arguments.Length == 1)
        {
            return n.ToString().ToCharArray();
        }
        int numbase = 10;
        if (arguments.Length == 2)
        {
            numbase = IntegerMath.ToInt(arguments[1]);
        }
        if (Value.IsInteger(arguments[0]))
        {
            if (arguments[0] is long lv)
            {
                return Convert.ToString(lv, numbase).ToCharArray();
            }
            BigInteger bv = IntegerMath.ToBigInteger(arguments[0]);
            if (numbase == 10) return bv.ToString().ToCharArray();
            if (numbase == 16) return bv.ToString("x").ToCharArray();
            return BigIntegerToBase(bv, numbase).ToCharArray();
        }
        else if (Value.IsRational(arguments[0]))
        {
            return Value.AsRational(arguments[0]).ToString().ToCharArray();
        }
        else if (Value.IsReal(arguments[0]))
        {
            return Value.FormatDouble(Value.AsReal(arguments[0])).ToCharArray();
        }
        throw new SchemeError(pos, "number->string: not a number: ~s", arguments[0]);
    }

    private static string BigIntegerToBase(BigInteger value, int numbase)
    {
        if (value.IsZero) return "0";
        bool negative = value < 0;
        if (negative) value = -value;
        const string digits = "0123456789abcdefghijklmnopqrstuvwxyz";
        var chars = new System.Collections.Generic.List<char>();
        while (value > 0)
        {
            BigInteger rem;
            value = BigInteger.DivRem(value, numbase, out rem);
            chars.Add(digits[(int)rem]);
        }
        if (negative) chars.Add('-');
        chars.Reverse();
        return new string(chars.ToArray());
    }
}
