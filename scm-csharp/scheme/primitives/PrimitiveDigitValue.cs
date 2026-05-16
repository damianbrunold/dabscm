namespace scheme;

public class PrimitiveDigitValue : Primitive
{
    public override string Name() => "digit-value";

    public override string Info() =>
        "Syntax: (digit-value char)\n" +
        "Library: (scheme char)\n" +
        "Description: Returns the numeric value (0-9) of a Unicode decimal digit character, or #f if the character is not a decimal digit.\n" +
        "Example:\n" +
        "  (digit-value #\\3) => 3\n" +
        "  (digit-value #\\a) => #f";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        char c = Value.AsChar(arguments[0]);
        if (char.IsDigit(c))
        {
            double v = char.GetNumericValue(c);
            if (v >= 0 && v <= 9) return (long)v;
        }
        return Value.F;
    }
}
