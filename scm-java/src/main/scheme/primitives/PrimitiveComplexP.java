package scheme;

public class PrimitiveComplexP extends Primitive {
    @Override public String name() { return "complex?"; }

    @Override public String info() {
        return
            "Syntax: (complex? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is a complex number, #f otherwise.\n" +
            "  In the R7RS numeric tower, all numbers are complex.\n" +
            "Example:\n" +
            "  (complex? 3+4i) => #t\n" +
            "  (complex? 3)    => #t";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        Object obj = arguments[0];
        return Value.isComplex(obj) || Value.isReal(obj) || Value.isInteger(obj) || Value.isRational(obj)
            ? Value.T : Value.F;
    }
}
