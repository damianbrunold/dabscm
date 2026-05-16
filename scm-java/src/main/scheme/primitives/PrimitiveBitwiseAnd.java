package scheme.primitives;

import scheme.*;

public class PrimitiveBitwiseAnd extends Primitive {
    @Override
    public String name() {
        return "bitwise-and";
    }

    @Override
    public String info() {
        return "Syntax: (bitwise-and i ...)\n" +
               "Library: (srfi 151)\n" +
               "Description: Returns the bitwise AND of its arguments. With no arguments,\n" +
               "returns -1 (all bits set).\n" +
               "Example:\n" +
               "  (bitwise-and 14 10) => 10\n" +
               "  (bitwise-and 14 10 12) => 8\n" +
               "  (bitwise-and) => -1";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        if (arguments.length == 0) return -1L;
        Object result = arguments[0];
        for (int i = 1; i < arguments.length; i++) {
            result = IntegerMath.bitwiseAnd(result, arguments[i]);
        }
        return result;
    }
}
