package scheme.primitives;

import java.util.Base64;
import scheme.*;

public class PrimitiveBase64Encode extends Primitive {
    @Override
    public String name() { return "base64-encode"; }

    @Override
    public String info() {
        return "Syntax: (base64-encode bytevector)\n" +
               "Library: (scm crypto)\n" +
               "Description: Returns the base64-encoded string of a bytevector.\n" +
               "Example:\n" +
               "  (base64-encode #u8(72 101 108 108 111)) => \"SGVsbG8=\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        byte[] bv = Value.asBytevector(arguments[0]);
        return Base64.getEncoder().encodeToString(bv).toCharArray();
    }
}
