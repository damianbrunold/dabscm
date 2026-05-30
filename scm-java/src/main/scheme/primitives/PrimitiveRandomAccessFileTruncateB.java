package scheme.primitives;

import scheme.*;

public class PrimitiveRandomAccessFileTruncateB extends Primitive {
    @Override public String name() { return "random-access-file-truncate!"; }
    @Override public String info() {
        return "Syntax: (random-access-file-truncate! f size)\n" +
               "Library: (scm random access)\n" +
               "Description: Sets the length of random-access file f to size bytes. Shrinks the file when size is smaller than the current length; extends it with zero bytes when larger. Returns an unspecified value.\n" +
               "Example:\n" +
               "  (random-access-file-truncate! f 0)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        RandomAccessFileHandle f = RandomAccessFileHandle.of(pos, arguments[0], name());
        long size = IntegerMath.toLong(arguments[1]);
        if (size < 0) throw new SchemeError(pos, name() + ": negative size, ~s", size);
        try {
            f.truncate(size);
            return new Values();
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~a", e.getMessage());
        }
    }
}
