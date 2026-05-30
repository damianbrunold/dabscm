package scheme.primitives;

import scheme.*;

public class PrimitiveRandomAccessFileP extends Primitive {
    @Override public String name() { return "random-access-file?"; }
    @Override public String info() {
        return "Syntax: (random-access-file? obj)\n" +
               "Library: (scm random access)\n" +
               "Description: Returns #t if obj is a random-access file handle (as returned by open-random-access-file), otherwise #f.\n" +
               "Example:\n" +
               "  (random-access-file? (open-random-access-file \"x\" 'write)) => #t\n" +
               "  (random-access-file? 42) => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isNativeValue(arguments[0])
                && Value.asNativeValue(arguments[0]).value instanceof RandomAccessFileHandle;
    }
}
