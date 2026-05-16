namespace scheme;

public class PrimitiveRationalNumerator : Primitive
{
    public override string Name() => "rational-numerator";
    public override string Info() =>
        "Syntax: (rational-numerator q)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns the numerator of the rational number q in lowest terms. Returns q itself for integers.\n" +
        "  For inexact rational numbers, returns the numerator as an inexact number.\n" +
        "Example:\n" +
        "  (rational-numerator 1/3) => 1\n" +
        "  (rational-numerator 5)   => 5\n" +
        "  (rational-numerator 1.5) => 3.0";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsInteger(arguments[0])) return arguments[0];
        if (Value.IsRational(arguments[0])) return Value.AsRational(arguments[0]).Numerator;
        if (Value.IsReal(arguments[0]))
        {
            double d = (double)arguments[0];
            if (!double.IsFinite(d))
                throw new SchemeError(pos, "numerator: not a rational number: " + d);
            return DoubleNumerator(d);
        }
        throw new SchemeError(pos, "numerator: not a rational number: ~s", arguments[0]);
    }

    internal static double DoubleNumerator(double d)
    {
        if (d == 0.0) return 0.0;
        var (n, _) = DoubleToReducedParts(d);
        return n;
    }

    internal static (double num, double den) DoubleToReducedParts(double d)
    {
        bool negative = d < 0;
        double absD = Math.Abs(d);
        long bits = BitConverter.DoubleToInt64Bits(absD);
        long mant = bits & 0x000FFFFFFFFFFFFFL;
        int biasedExp = (int)((bits >> 52) & 0x7FF);
        long n;
        int shift;
        if (biasedExp == 0)
        {
            n = mant;
            shift = 1074;
        }
        else
        {
            n = mant | (1L << 52);
            shift = 1023 + 52 - biasedExp;
        }
        if (shift <= 0)
        {
            // integer-valued double
            double numD = negative ? -absD : absD;
            return (numD, 1.0);
        }
        int tz = TrailingZeros64(n);
        int reduce = Math.Min(tz, shift);
        n >>= reduce;
        shift -= reduce;
        double num = negative ? -(double)n : (double)n;
        double den = shift <= 62 ? (double)(1L << shift) : double.PositiveInfinity;
        return (num, den);
    }

    private static int TrailingZeros64(long n)
    {
        if (n == 0) return 64;
        int count = 0;
        while ((n & 1L) == 0) { n >>= 1; count++; }
        return count;
    }
}
