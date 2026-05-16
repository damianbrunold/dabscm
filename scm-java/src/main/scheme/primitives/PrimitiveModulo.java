package scheme.primitives;

import scheme.*;

public class PrimitiveModulo extends Primitive {
    @Override
    public String name() {
        return "modulo";
    }

    @Override
    public String info() {
        return "Syntax: (modulo n1 n2)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns the integer modulus of n1 divided by n2. The result has the same sign as n2.\n" +
               "Example:\n" +
               "  (modulo 13 4) => 1\n" +
               "  (modulo -13 4) => 3\n" +
               "  (modulo 13 -4) => -3";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        if (allIntegers(arguments)) {
            return IntegerMath.genericModulo(arguments[0], arguments[1]);
        }
        else {
            double a = toReal(arguments[0]);
            double b = toReal(arguments[1]);
            double r = a % b;
            if ((r >= 0) != (b >= 0)) {
                return r + b;
            }
            return r;
        }
    }
}
