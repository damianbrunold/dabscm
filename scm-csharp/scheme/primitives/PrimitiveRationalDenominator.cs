namespace scheme;

public class PrimitiveRationalDenominator : Primitive
{
    public override string Name() => "rational-denominator";
    public override string Info() =>
        "Syntax: (rational-denominator q)\n" +
        "Library: (scm core)\n" +
        "Description: Returns the denominator of the rational number q in lowest terms. Returns 1 for integers.\n" +
        "  For inexact rational numbers, returns the denominator as an inexact number.\n" +
        "Example:\n" +
        "  (rational-denominator 1/3) => 3\n" +
        "  (rational-denominator 5)   => 1\n" +
        "  (rational-denominator 1.5) => 2.0";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsInteger(arguments[0])) return 1L;
        if (Value.IsRational(arguments[0])) return Value.AsRational(arguments[0]).Denominator;
        if (Value.IsReal(arguments[0]))
        {
            double d = (double)arguments[0];
            if (!double.IsFinite(d))
                throw new SchemeError(pos, "denominator: not a rational number: " + d);
            var (_, den) = PrimitiveRationalNumerator.DoubleToReducedParts(d);
            return den;
        }
        throw new SchemeError(pos, "denominator: not a rational number: ~s", arguments[0]);
    }
}
