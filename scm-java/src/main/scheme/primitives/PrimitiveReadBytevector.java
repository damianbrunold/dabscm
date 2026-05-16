package scheme.primitives;

import scheme.*;

public class PrimitiveReadBytevector extends Primitive {
    @Override public String name() { return "read-bytevector"; }
    @Override public String info() {
        return "Syntax: (read-bytevector k port)\n" +
               "Library: (scheme base)\n" +
               "Description: Reads up to k bytes from the binary input port and returns them as a freshly allocated bytevector. Returns an end-of-file object if no bytes are available.\n" +
               "Example:\n" +
               "  (let ((p (open-input-bytevector #u8(1 2 3))))\n" +
               "    (read-bytevector 2 p)) => #u8(1 2)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        try {
            int k = IntegerMath.toInt(arguments[0]);
            BinaryInputStream port = Value.asBinaryInputPort(arguments[1]);
            if (k == 0) return new byte[0];
            byte[] buf = new byte[k];
            int read = 0;
            while (read < k) {
                int b = port.readByte();
                if (b == -1) break;
                buf[read++] = (byte) b;
            }
            if (read == 0) return Value.EOF;
            if (read < k) {
                byte[] shorter = new byte[read];
                System.arraycopy(buf, 0, shorter, 0, read);
                return shorter;
            }
            return buf;
        } catch (Exception e) {
            throw new SchemeError(pos, "read-bytevector: io failure: ~a", e.getMessage());
        }
    }
}
