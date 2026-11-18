package scheme.primitives;

import scheme.*;

public class PrimitiveStringToLatin1 extends Primitive {
    @Override
    public String name() {
        return "string->latin1";
    }

    @Override
    public String info() {
        return "Syntax: (string->latin1 s [replacement [start [end]]])\n" +
               "Library: (scm bytevector)\n" +
               "Description: Encodes the string s (or its range from start to end) as\n" +
               "ISO-8859-1 (Latin-1) and returns a bytevector. A character above #xFF\n" +
               "(a surrogate pair counts as one character) is an error unless\n" +
               "replacement is given: a byte value 0-255 written in its place.\n" +
               "Example:\n" +
               "  (string->latin1 \"a\\xE4;\") => #u8(97 228)\n" +
               "  (string->latin1 \"a\\x20AC;\" 63) => #u8(97 63)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 4);
        char[] s = Value.asString(arguments[0]);
        int replacement = -1;
        if (arguments.length > 1 && arguments[1] != Value.F) {
            replacement = IntegerMath.toInt(arguments[1]);
            if (replacement < 0 || replacement > 255)
                throw new SchemeError(pos, "string->latin1: replacement ~a is not a byte", (long) replacement);
        }
        int start = arguments.length > 2 ? IntegerMath.toInt(arguments[2]) : 0;
        int end = arguments.length > 3 ? IntegerMath.toInt(arguments[3]) : s.length;
        if (start < 0 || end > s.length || start > end)
            throw new SchemeError(pos, "string->latin1: invalid range");
        byte[] out = new byte[end - start];
        int n = 0;
        for (int i = start; i < end; i++) {
            char c = s[i];
            if (c <= 0xFF) {
                out[n++] = (byte) c;
                continue;
            }
            if (replacement < 0)
                throw new SchemeError(pos, "string->latin1: character #x~a at index ~a has no Latin-1 encoding",
                                      Integer.toHexString(c).toUpperCase(), (long) i);
            out[n++] = (byte) replacement;
            if (Character.isHighSurrogate(c) && i + 1 < end && Character.isLowSurrogate(s[i + 1])) i++;
        }
        if (n == out.length) return out;
        byte[] trimmed = new byte[n];
        System.arraycopy(out, 0, trimmed, 0, n);
        return trimmed;
    }
}
