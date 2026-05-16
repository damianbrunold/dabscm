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
        return Complex.create(arguments[0], arguments[1]);
    }
}
