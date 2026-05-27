namespace scheme;

public class PrimitiveComplexRealPart : Primitive
{
    public override string Name()
    {
        return "complex-real-part";
    }

    public override string Info()
    {
        return
            "Syntax: (complex-real-part z)\n" +
            "Library: (scm core)\n" +
            "Description: Returns the real part of the complex number z.\n" +
            "Example:\n" +
            "  (complex-real-part 1+2i) => 1";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsComplex(arguments[0]))
            return Value.AsComplex(arguments[0]).Real;
        throw new SchemeError(pos, "complex-real-part: not a complex number: ~s", arguments[0]);
    }
}
