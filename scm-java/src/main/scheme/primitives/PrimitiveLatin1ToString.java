package scheme.primitives;

import scheme.*;

public class PrimitiveLatin1ToString extends Primitive {
    @Override
    public String name() {
        return "latin1->string";
    }

    @Override
    public String info() {
        return "Syntax: (latin1->string bv [start [end]])\n" +
               "Library: (scm bytevector)\n" +
               "Description: Decodes the bytes of bv (or its range from start to end)\n" +
               "as ISO-8859-1 (Latin-1): each byte becomes the character with the same\n" +
               "code. Never fails.\n" +
               "Example:\n" +
               "  (latin1->string (bytevector #x61 #xE4)) => \"a\\xE4;\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        byte[] bv = Value.asBytevector(arguments[0]);
        int start = arguments.length > 1 ? IntegerMath.toInt(arguments[1]) : 0;
        int end = arguments.length > 2 ? IntegerMath.toInt(arguments[2]) : bv.length;
        if (start < 0 || end > bv.length || start > end)
            throw new SchemeError(pos, "latin1->string: invalid range");
        char[] result = new char[end - start];
        for (int i = start; i < end; i++) result[i - start] = (char) (bv[i] & 0xFF);
        return result;
    }
}
