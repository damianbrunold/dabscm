package scheme.primitives;

import scheme.*;
import java.nio.charset.StandardCharsets;

public class PrimitiveStringToUtf8 extends Primitive {
    @Override public String name() { return "string->utf8"; }
    @Override public String info() {
        return "Syntax: (string->utf8 s start? end?)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns a bytevector containing the UTF-8 encoding of the string s. Optional start and end indices can be used to encode a substring.\n" +
               "Example:\n" +
               "  (string->utf8 \"abc\") => #u8(97 98 99)\n" +
               "  (string->utf8 \"hello\" 1 3) => #u8(101 108)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        char[] s = Value.asString(arguments[0]);
        int start = arguments.length >= 2 ? IntegerMath.toInt(arguments[1]) : 0;
        int end = arguments.length >= 3 ? IntegerMath.toInt(arguments[2]) : s.length;
        if (start < 0 || end > s.length || start > end)
            throw new SchemeError(pos, "string->utf8: invalid range");
        return new String(s, start, end - start).getBytes(StandardCharsets.UTF_8);
    }
}
