package scheme.primitives;

import scheme.*;

public class PrimitiveXorKey extends Primitive {
    @Override
    public String name() {
        return "xor-key";
    }

    @Override
    public String info() {
        return "Syntax: (xor-key bv key)\n" +
               "Library: (scm crypto)\n" +
               "Description: Returns a new bytevector produced by XORing each byte of bv with the corresponding byte of key, cycling through key as needed.\n" +
               "Example:\n" +
               "  (xor-key data-bv key-bv) => #u8(...)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        var value = Value.asBytevector(arguments[0]);
        var key = Value.asBytevector(arguments[1]);
        var result = new byte[value.length];
        var j = 0;
        for (var i = 0; i < value.length; i++) {
            if (j >= key.length) j = 0;
            result[i] = (byte) (value[i] ^ key[j]);
            j++;
        }
        return result;
    }
}
