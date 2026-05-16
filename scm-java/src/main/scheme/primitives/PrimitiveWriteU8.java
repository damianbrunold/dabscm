package scheme.primitives;

import scheme.*;

public class PrimitiveWriteU8 extends Primitive {
    @Override public String name() { return "write-u8"; }
    @Override public String info() {
        return "Syntax: (write-u8 byte port?)\n" +
               "Library: (scheme base)\n" +
               "Description: Writes a single byte (an exact integer in the range 0-255) to the given binary output port.\n" +
               "Example:\n" +
               "  (write-u8 65 port)\n" +
               "  (write-u8 0 port)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        try {
            long b = IntegerMath.toLong(arguments[0]);
            if (b < 0 || b > 255) throw new SchemeError(pos, "write-u8: byte out of range: ~s", b);
            Value.asBinaryOutputPort(arguments[1]).writeByte((byte) b);
            return new Values();
        } catch (SchemeError e) { throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, "write-u8: io failure: ~a", e.getMessage());
        }
    }
}
