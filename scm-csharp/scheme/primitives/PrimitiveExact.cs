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

    /// <summary>
    /// Convert a non-integral double to the simplest rational whose double
    /// representation equals d, using the continued fraction algorithm.
    /// </summary>
    private static object DoubleToRational(double d)
    {
        bool negative = d < 0;
        double x = Math.Abs(d);

        // Continued fraction convergents: p[-1]/q[-1] = 1/0, p[0]/q[0] = 0/1
        long p0 = 0, q0 = 1;
        long p1 = 1, q1 = 0;

        double rem = x;
        for (int i = 0; i < 100; i++) // safety limit
        {
            long a = (long)Math.Floor(rem);

            // Next convergent: p2/q2 = a * p1 + p0, a * q1 + q0
            long p2 = a * p1 + p0;
            long q2 = a * q1 + q0;

            // Check if this convergent equals d when converted back to double
            if (q2 != 0 && (double)p2 / (double)q2 == x)
            {
                if (negative) p2 = -p2;
                if (q2 == 1) return p2;
                return Rational.Create(p2, q2);
            }

            // Prepare for next iteration
            double frac = rem - a;
            if (frac == 0.0) break; // exact integer (shouldn't reach here)
            rem = 1.0 / frac;

            p0 = p1; q0 = q1;
            p1 = p2; q1 = q2;

            // Guard against overflow
            if (p1 > long.MaxValue / 1000 || q1 > long.MaxValue / 1000) break;
        }

        // Fallback: return the last convergent even if not exact
        if (negative) p1 = -p1;
        if (q1 == 1) return p1;
        return Rational.Create(p1, q1);
    }
}
