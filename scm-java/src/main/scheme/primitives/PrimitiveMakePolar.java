package scheme;

public class PrimitiveMakePolar extends Primitive {
    @Override public String name() { return "make-polar"; }

    @Override public String info() {
        return
            "Syntax: (make-polar r theta)\n" +
            "Library: (scheme complex)\n" +
            "Description: Returns the complex number r * e^(i*theta).\n" +
            "Example:\n" +
            "  (make-polar 1 0) => 1.0\n" +
            "  (make-polar 1 1) => 0.5403023058681398+0.8414709848078965i";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        double r = toReal(arguments[0]);
        double theta = toReal(arguments[1]);
        return Complex.create(r * Math.cos(theta), r * Math.sin(theta));
    }
}
