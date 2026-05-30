package scheme.primitives;

import scheme.*;

public class PrimitiveRandomAccessFileSize extends Primitive {
    @Override public String name() { return "random-access-file-size"; }
    @Override public String info() {
        return "Syntax: (random-access-file-size f)\n" +
               "Library: (scm random access)\n" +
               "Description: Returns the current size of random-access file f in bytes.\n" +
               "Example:\n" +
               "  (random-access-file-size f) => 1024";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        RandomAccessFileHandle f = RandomAccessFileHandle.of(pos, arguments[0], name());
        try {
            return f.size();
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~a", e.getMessage());
        }
    }
}
