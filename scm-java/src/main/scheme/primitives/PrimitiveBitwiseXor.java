package scheme.primitives;

import scheme.*;

public class PrimitiveBitwiseXor extends Primitive {
    @Override
    public String name() {
        return "bitwise-xor";
    }

    @Override
    public String info() {
        return "Syntax: (bitwise-xor i ...)\n" +
               "Library: (srfi 151)\n" +
               "Description: Returns the bitwise exclusive OR of its arguments. With no\n" +
               "arguments, returns 0.\n" +
               "Example:\n" +
               "  (bitwise-xor 10 12) => 6\n" +
               "  (bitwise-xor) => 0";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        if (arguments.length == 0) return 0L;
        Object result = arguments[0];
        for (int i = 1; i < arguments.length; i++) {
            result = IntegerMath.bitwiseXor(result, arguments[i]);
        }
        return result;
    }
}
