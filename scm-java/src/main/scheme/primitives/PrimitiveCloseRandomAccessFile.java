package scheme.primitives;

import scheme.*;

public class PrimitiveCloseRandomAccessFile extends Primitive {
    @Override public String name() { return "close-random-access-file"; }
    @Override public String info() {
        return "Syntax: (close-random-access-file f)\n" +
               "Library: (scm random access)\n" +
               "Description: Closes random-access file f, flushing and releasing the underlying file. Closing an already-closed handle is harmless. Returns an unspecified value.\n" +
               "Example:\n" +
               "  (close-random-access-file f)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        RandomAccessFileHandle f = RandomAccessFileHandle.of(pos, arguments[0], name());
        try {
            f.close();
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~a", e.getMessage());
        }
    }
}
