package scheme.primitives;

import scheme.*;

public class PrimitiveBytevectorCopy extends Primitive {
    @Override public String name() { return "bytevector-copy"; }
    @Override public String info() {
        return "Syntax: (bytevector-copy bv) (bytevector-copy bv start) (bytevector-copy bv start end)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a newly allocated copy of the elements of bv from start (inclusive) to end (exclusive).\n" +
               "Example:\n" +
               "  (bytevector-copy #u8(1 2 3)) => #u8(1 2 3)\n" +
               "  (bytevector-copy #u8(1 2 3) 1 2) => #u8(2)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        byte[] bv = Value.asBytevector(arguments[0]);
        int start = arguments.length >= 2 ? IntegerMath.toInt(arguments[1]) : 0;
        int end = arguments.length >= 3 ? IntegerMath.toInt(arguments[2]) : bv.length;
        if (start < 0 || end > bv.length || start > end)
            throw new SchemeError(pos, "bytevector-copy: invalid range ~s ~s", start, end);
        byte[] result = new byte[end - start];
        System.arraycopy(bv, start, result, 0, end - start);
        return result;
    }
}
