package scheme.primitives;

import java.util.Base64;
import scheme.*;

public class PrimitiveBase64Decode extends Primitive {
    @Override
    public String name() { return "base64-decode"; }

    @Override
    public String info() {
        return "Syntax: (base64-decode string)\n" +
               "Library: (scm crypto)\n" +
               "Description: Decodes a base64-encoded string and returns a bytevector.\n" +
               "Example:\n" +
               "  (base64-decode \"SGVsbG8=\") => #u8(72 101 108 108 111)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        String s = new String(Value.asString(arguments[0]));
        return Base64.getDecoder().decode(s);
    }
}
