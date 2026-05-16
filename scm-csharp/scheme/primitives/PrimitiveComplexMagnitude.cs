namespace scheme;

public class PrimitiveComplexMagnitude : Primitive
{
    public override string Name()
    {
        return "complex-magnitude";
    }

    public override string Info()
    {
        return
            "Syntax: (complex-magnitude z)\n" +
            "Library: (scheme complex)\n" +
            "Description: Returns the magnitude of the complex number z.\n" +
            "Example:\n" +
            "  (complex-magnitude 3+4i) => 5.0";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsComplex(arguments[0]))
            return Complex.Magnitude(Value.AsComplex(arguments[0]));
        throw new SchemeError(pos, "complex-magnitude: not a complex number: ~s", arguments[0]);
    }
}
