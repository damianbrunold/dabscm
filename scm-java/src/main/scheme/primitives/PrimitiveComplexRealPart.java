package scheme;

public class PrimitiveComplexRealPart extends Primitive {
    @Override public String name() { return "complex-real-part"; }

    @Override public String info() {
        return
            "Syntax: (complex-real-part z)\n" +
            "Library: (scheme complex)\n" +
            "Description: Returns the real part of the complex number z.\n" +
            "Example:\n" +
            "  (complex-real-part 1+2i) => 1";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isComplex(arguments[0]))
            return Value.asComplex(arguments[0]).real;
        throw new SchemeError(pos, "complex-real-part: not a complex number: ~s", arguments[0]);
    }
}
