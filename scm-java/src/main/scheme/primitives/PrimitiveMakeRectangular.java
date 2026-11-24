package scheme;

public class PrimitiveMakeRectangular extends Primitive {
    @Override public String name() { return "make-rectangular"; }

    @Override public String info() {
        return
            "Syntax: (make-rectangular x y)\n" +
            "Library: (scheme complex)\n" +
            "Description: Returns the complex number x + yi.\n" +
            "Example:\n" +
            "  (make-rectangular 1 2) => 1+2i\n" +
            "  (make-rectangular 3 0) => 3";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        for (Object a : arguments)
            if (!isRealNumber(a)) throw new WrongTypeException(a, "real number");
        return Complex.create(arguments[0], arguments[1]);
    }

    static boolean isRealNumber(Object a) {
        return a instanceof Long || a instanceof Double || a instanceof java.math.BigInteger || a instanceof Rational;
    }
}
