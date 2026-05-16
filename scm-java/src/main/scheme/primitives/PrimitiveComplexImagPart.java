package scheme;

public class PrimitiveComplexImagPart extends Primitive {
    @Override public String name() { return "complex-imag-part"; }

    @Override public String info() {
        return
            "Syntax: (complex-imag-part z)\n" +
            "Library: (scheme complex)\n" +
            "Description: Returns the imaginary part of the complex number z.\n" +
            "Example:\n" +
            "  (complex-imag-part 1+2i) => 2";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isComplex(arguments[0]))
            return Value.asComplex(arguments[0]).imag;
        throw new SchemeError(pos, "complex-imag-part: not a complex number: ~s", arguments[0]);
    }
}
