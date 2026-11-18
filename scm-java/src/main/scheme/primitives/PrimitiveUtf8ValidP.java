package scheme.primitives;

import scheme.*;

import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;

public class PrimitiveUtf8ValidP extends Primitive {
    @Override
    public String name() {
        return "utf8-valid?";
    }

    @Override
    public String info() {
        return "Syntax: (utf8-valid? bv [start [end]])\n" +
               "Library: (scm bytevector)\n" +
               "Description: Returns #t if the bytes of bv (or its range from start to\n" +
               "end) are well-formed UTF-8, #f otherwise. Use it to decide whether\n" +
               "utf8->string would replace any bytes with U+FFFD, for example to tell\n" +
               "UTF-8 files from Latin-1 ones.\n" +
               "Example:\n" +
               "  (utf8-valid? (bytevector #xC3 #xA4)) => #t\n" +
               "  (utf8-valid? (bytevector #xE4)) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        byte[] bv = Value.asBytevector(arguments[0]);
        int start = arguments.length > 1 ? IntegerMath.toInt(arguments[1]) : 0;
        int end = arguments.length > 2 ? IntegerMath.toInt(arguments[2]) : bv.length;
        if (start < 0 || end > bv.length || start > end)
            throw new SchemeError(pos, "utf8-valid?: invalid range");
        try {
            StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(bv, start, end - start));
            return true;
        } catch (CharacterCodingException e) {
            return false;
        }
    }
}
