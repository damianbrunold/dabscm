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
        if (numbase < 2 || numbase > 36)
            throw new SchemeError(pos, "number->string: bad radix: ~s", arguments[1]);
        if (Value.IsComplex(arguments[0]))
        {
            Complex c = Value.AsComplex(arguments[0]);
            // an exact complex number: both parts in the radix ((number->string 1+2i 2) is "1+10i")
            if (numbase == 10 || !Complex.IsExact(c.Real)) return c.ToString().ToCharArray();
            object imag = c.Imag;
            bool negative = IntegerMath.IsNegative(imag is Rational ri ? ri.Numerator : imag);
            if (negative) imag = Complex.PartNegate(imag);
            return (FormatExact(c.Real, numbase) + (negative ? "-" : "+") + FormatExact(imag, numbase) + "i").ToCharArray();
        }
        if (Value.IsInteger(arguments[0]) || Value.IsRational(arguments[0]))
            return FormatExact(arguments[0], numbase).ToCharArray();
        else if (Value.IsReal(arguments[0]))
        {
            return Value.FormatDouble(Value.AsReal(arguments[0])).ToCharArray();
        }
        throw new SchemeError(pos, "number->string: not a number: ~s", arguments[0]);
    }

    // an exact integer or rational in the radix, in sign and magnitude (not
    // the two's complement)
    private static string FormatExact(object v, int numbase)
    {
        if (v is Rational r)
        {
            if (numbase == 10) return r.ToString();
            return BigIntegerToBase(IntegerMath.ToBigInteger(r.Numerator), numbase) + "/" +
                   BigIntegerToBase(IntegerMath.ToBigInteger(r.Denominator), numbase);
        }
        if (numbase == 10) return v.ToString()!;
        return BigIntegerToBase(IntegerMath.ToBigInteger(v), numbase);
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
