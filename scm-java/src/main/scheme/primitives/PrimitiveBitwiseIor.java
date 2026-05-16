package scheme.primitives;

import scheme.*;

public class PrimitiveBitwiseIor extends Primitive {
    @Override
    public String name() {
        return "bitwise-ior";
    }

    @Override
    public String info() {
        return "Syntax: (bitwise-ior i ...)\n" +
               "Library: (srfi 151)\n" +
               "Description: Returns the bitwise inclusive OR of its arguments. With no\n" +
               "arguments, returns 0.\n" +
               "Example:\n" +
               "  (bitwise-ior 10 12) => 14\n" +
               "  (bitwise-ior) => 0";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        if (arguments.length == 0) return 0L;
        Object result = arguments[0];
        for (int i = 1; i < arguments.length; i++) {
            result = IntegerMath.bitwiseIor(result, arguments[i]);
        }
        return result;
    }
}
