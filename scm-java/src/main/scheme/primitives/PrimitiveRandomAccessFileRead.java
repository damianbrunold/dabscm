package scheme.primitives;

import scheme.*;

public class PrimitiveRandomAccessFileRead extends Primitive {
    @Override public String name() { return "random-access-file-read"; }
    @Override public String info() {
        return "Syntax: (random-access-file-read f offset count)\n" +
               "Library: (scm random access)\n" +
               "Description: Reads up to count bytes from random-access file f starting at byte offset and returns them as a freshly allocated bytevector. The returned bytevector is shorter than count (possibly empty) when the read reaches end of file. Does not affect any other read or write.\n" +
               "Example:\n" +
               "  (random-access-file-read f 0 4) => #u8(1 2 3 4)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 3);
        RandomAccessFileHandle f = RandomAccessFileHandle.of(pos, arguments[0], name());
        long offset = IntegerMath.toLong(arguments[1]);
        int count = IntegerMath.toInt(arguments[2]);
        if (offset < 0) throw new SchemeError(pos, name() + ": negative offset, ~s", offset);
        try {
            return f.read(offset, count);
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~a", e.getMessage());
        }
    }
}
