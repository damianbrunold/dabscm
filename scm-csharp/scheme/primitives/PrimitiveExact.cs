using System.Numerics;

namespace scheme;

public class PrimitiveExact : Primitive
{
    public override string Name()
    {
        return "exact";
    }

    public override string Info()
    {
        return
            "Syntax: (exact z)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the exact number that is numerically equal to z.\n" +
            "  For inexact integers, returns the integer. For non-integral inexact\n" +
            "  numbers, returns the simplest exact rational whose inexact value\n" +
            "  equals z (using continued fraction approximation).\n" +
            "Example:\n" +
            "  (exact 1.5) => 3/2\n" +
            "  (exact 0.3) => 3/10\n" +
            "  (exact 3.0) => 3\n" +
            "  (exact 3) => 3";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsInteger(arguments[0])) return arguments[0];
        if (Value.IsRational(arguments[0])) return arguments[0];
        if (Value.IsComplex(arguments[0]))
        {
            Complex c = Value.AsComplex(arguments[0]);
            return Complex.Create(Complex.ToExact(c.Real), Complex.ToExact(c.Imag));
        }
        double d = Value.AsReal(arguments[0]);

        if (double.IsNaN(d) || double.IsInfinity(d))
            throw new SchemeError(pos, "exact: no exact representation for ~a", arguments[0]);

        // Integral doubles → integer
        if (d == Math.Floor(d))
        {
            if (d >= long.MinValue && d <= long.MaxValue)
                return (long)d;
            else
                return (BigInteger)d;
        }

        // Non-integral doubles → simplest exact rational via continued fractions.
        // Finds the rational with the smallest denominator whose (double) value
        // equals d. E.g. 0.3 → 3/10 (since (double)(3/10) == 0.3).
        return DoubleToRational(d);
    }

    // The simplest rational (smallest denominator) that reads back as d: the
    // simplest one in d's rounding interval, halfway to the neighbouring
    // doubles with both ends included on a tie-to-even. Computed exactly, so
    // it works across the whole range, subnormals included.
    private static object DoubleToRational(double d)
    {
        bool negative = d < 0;
        double x = Math.Abs(d);   // > 0 and not integral (handled by the caller)
        ExactParts(x, out BigInteger n, out BigInteger m);
        ExactParts(Math.BitDecrement(x), out BigInteger pn, out BigInteger pm);
        ExactParts(Math.BitIncrement(x), out BigInteger nn, out BigInteger nm);
        BigInteger loN = n * pm + pn * m, loD = 2 * m * pm;
        BigInteger hiN = n * nm + nn * m, hiD = 2 * m * nm;
        bool closed = (BitConverter.DoubleToInt64Bits(x) & 1) == 0;

        // Continued fraction of the simplest rational between lo and hi: take
        // an integer in the interval if there is one, else the common integer
        // part and continue with the reciprocals of the fractional parts
        // (which swaps the ends). hiD == 0 stands for +infinity.
        var terms = new List<BigInteger>();
        while (true)
        {
            BigInteger fl = BigInteger.Divide(loN, loD);
            BigInteger c = closed && fl * loD == loN ? fl : fl + 1;
            int cmp = hiD.IsZero ? -1 : (c * hiD).CompareTo(hiN);
            if (cmp < 0 || (closed && cmp == 0)) { terms.Add(c); break; }
            terms.Add(fl);
            BigInteger nLoN = hiD, nLoD = hiN - fl * hiD;   // 1 / (hi - fl)
            BigInteger nHiN = loD, nHiD = loN - fl * loD;   // 1 / (lo - fl)
            loN = nLoN; loD = nLoD; hiN = nHiN; hiD = nHiD;
        }
        BigInteger p = terms[terms.Count - 1], q = BigInteger.One;
        for (int i = terms.Count - 2; i >= 0; i--)
            (p, q) = (terms[i] * p + q, p);
        return Rational.Create(IntegerMath.Normalize(negative ? -p : p), IntegerMath.Normalize(q));
    }

    // x (finite, >= 0) as num/den.
    private static void ExactParts(double x, out BigInteger num, out BigInteger den)
    {
        long bits = BitConverter.DoubleToInt64Bits(x);
        int biased = (int)((bits >> 52) & 0x7FF);
        long mantissa = bits & 0xFFFFFFFFFFFFF;
        if (biased != 0) mantissa |= 1L << 52; else biased = 1;
        int exp = biased - 1023 - 52;
        num = mantissa;
        den = BigInteger.One;
        if (exp >= 0) num <<= exp; else den <<= -exp;
    }
}
