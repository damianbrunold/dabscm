
package scheme.primitives;

import scheme.*;

public class PrimitiveNumberToString extends Primitive {

    @Override
    public String name() {
        return "number->string";
    }

    @Override
    public String info() {
        return "Syntax: (number->string z) (number->string z radix)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a string representation of z in the given radix (default 10). Exact integers support any radix.\n" +
               "Example:\n" +
               "  (number->string 42) => \"42\"\n" +
               "  (number->string 255 16) => \"ff\"\n" +
               "  (number->string 3.14) => \"3.14\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        // Fast path: single integer argument (most common case)
        if (arguments[0] instanceof Long && arguments.length == 1) {
            return ((Long) arguments[0]).toString().toCharArray();
        }
        int base = 10;
        if (arguments.length == 2) base = IntegerMath.toInt(arguments[1]);
        if (Value.isComplex(arguments[0])) {
            return Value.asComplex(arguments[0]).toString().toCharArray();
        } else if (Value.isInteger(arguments[0])) {
            return IntegerMath.toBigInteger(arguments[0]).toString(base).toCharArray();
        } else if (Value.isRational(arguments[0])) {
            return Value.asRational(arguments[0]).toString().toCharArray();
        } else if (Value.isReal(arguments[0])) {
            return Value.formatDouble(Value.asReal(arguments[0])).toCharArray();
        }
        throw new SchemeError(pos, "number->string: not a number: ~s", arguments[0]);
    }
}
