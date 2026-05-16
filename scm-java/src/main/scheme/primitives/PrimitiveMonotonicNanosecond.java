package scheme.primitives;

import scheme.Pair;
import scheme.Primitive;
import scheme.SourcePos;

public class PrimitiveMonotonicNanosecond extends Primitive {
    @Override
    public String name() {
        return "%monotonic-nanosecond";
    }

    @Override
    public String info() {
        return "Syntax: (%monotonic-nanosecond)\n" +
               "Library: (srfi 19)\n" +
               "Description: Internal primitive. Returns monotonic clock time as a pair (seconds . nanoseconds).\n" +
               "Example:\n" +
               "  (%monotonic-nanosecond) => (12345 . 678000000)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        long nanoTime = System.nanoTime();
        long seconds = nanoTime / 1_000_000_000L;
        long nanos = nanoTime % 1_000_000_000L;
        if (nanos < 0) {
            seconds -= 1;
            nanos += 1_000_000_000L;
        }
        return new Pair(seconds, nanos);
    }
}
