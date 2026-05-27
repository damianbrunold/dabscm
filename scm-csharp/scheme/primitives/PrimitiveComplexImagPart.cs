namespace scheme;

public class PrimitiveComplexImagPart : Primitive
{
    public override string Name()
    {
        return "complex-imag-part";
    }

    public override string Info()
    {
        return
            "Syntax: (complex-imag-part z)\n" +
            "Library: (scm core)\n" +
            "Description: Returns the imaginary part of the complex number z.\n" +
            "Example:\n" +
            "  (complex-imag-part 1+2i) => 2";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsComplex(arguments[0]))
            return Value.AsComplex(arguments[0]).Imag;
        throw new SchemeError(pos, "complex-imag-part: not a complex number: ~s", arguments[0]);
    }
}
