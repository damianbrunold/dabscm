package scheme.primitives;

import scheme.*;

public class PrimitiveRandomAccessFileFlush extends Primitive {
    @Override public String name() { return "random-access-file-flush"; }
    @Override public String info() {
        return "Syntax: (random-access-file-flush f)\n" +
               "Library: (scm random access)\n" +
               "Description: Flushes any buffered writes for random-access file f to the underlying storage. Returns an unspecified value.\n" +
               "Example:\n" +
               "  (random-access-file-flush f)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        RandomAccessFileHandle f = RandomAccessFileHandle.of(pos, arguments[0], name());
        try {
            f.flush();
            return new Values();
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~a", e.getMessage());
        }
    }
}
