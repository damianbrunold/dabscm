package scheme.primitives;

import scheme.*;
import java.nio.charset.StandardCharsets;

public class PrimitiveUtf8ToString extends Primitive {
    @Override public String name() { return "utf8->string"; }
    @Override public String info() {
        return "Syntax: (utf8->string bv start? end?)\n" +
               "Library: (scheme base)\n" +
               "Description: Decodes the UTF-8 encoded bytes in bytevector bv (optionally from start to end) and returns the result as a string.\n" +
               "Example:\n" +
               "  (utf8->string #u8(104 101 108 108 111)) => \"hello\"\n" +
               "  (utf8->string #u8(104 101 108 108 111) 1 3) => \"el\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        byte[] bv = Value.asBytevector(arguments[0]);
        int start = arguments.length >= 2 ? IntegerMath.toInt(arguments[1]) : 0;
        int end = arguments.length >= 3 ? IntegerMath.toInt(arguments[2]) : bv.length;
        if (start < 0 || end > bv.length || start > end)
            throw new SchemeError(pos, "utf8->string: invalid range");
        return new String(bv, start, end - start, StandardCharsets.UTF_8).toCharArray();
    }
}
