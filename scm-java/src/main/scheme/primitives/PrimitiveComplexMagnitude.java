package scheme;

public class PrimitiveComplexMagnitude extends Primitive {
    @Override public String name() { return "complex-magnitude"; }

    @Override public String info() {
        return
            "Syntax: (complex-magnitude z)\n" +
            "Library: (scheme complex)\n" +
            "Description: Returns the magnitude of the complex number z.\n" +
            "Example:\n" +
            "  (complex-magnitude 3+4i) => 5.0";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isComplex(arguments[0]))
            return Complex.magnitude(Value.asComplex(arguments[0]));
        throw new SchemeError(pos, "complex-magnitude: not a complex number: ~s", arguments[0]);
    }
}
