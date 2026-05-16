package scheme;

public class PrimitiveComplexAngle extends Primitive {
    @Override public String name() { return "complex-angle"; }

    @Override public String info() {
        return
            "Syntax: (complex-angle z)\n" +
            "Library: (scheme complex)\n" +
            "Description: Returns the angle (argument) of the complex number z in radians.\n" +
            "Example:\n" +
            "  (complex-angle 1+1i) => 0.7853981633974483";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        if (Value.isComplex(arguments[0]))
            return Complex.angle(Value.asComplex(arguments[0]));
        throw new SchemeError(pos, "complex-angle: not a complex number: ~s", arguments[0]);
    }
}
