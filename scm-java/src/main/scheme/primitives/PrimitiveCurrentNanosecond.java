package scheme.primitives;

import scheme.Pair;
import scheme.Primitive;
import scheme.SourcePos;

public class PrimitiveCurrentNanosecond extends Primitive {
    @Override
    public String name() {
        return "%current-nanosecond";
    }

    @Override
    public String info() {
        return "Syntax: (%current-nanosecond)\n" +
               "Library: (srfi 19)\n" +
               "Description: Internal primitive. Returns the current UTC time as a pair (seconds . nanoseconds) since the Unix epoch.\n" +
               "Example:\n" +
               "  (%current-nanosecond) => (1700000000 . 123456789)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        var now = java.time.Instant.now();
        return new Pair(now.getEpochSecond(), (long) now.getNano());
    }
}
