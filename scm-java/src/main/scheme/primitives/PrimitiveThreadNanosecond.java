package scheme.primitives;

import scheme.Pair;
import scheme.Primitive;
import scheme.SourcePos;

import java.lang.management.ManagementFactory;

public class PrimitiveThreadNanosecond extends Primitive {
    @Override
    public String name() {
        return "%thread-nanosecond";
    }

    @Override
    public String info() {
        return "Syntax: (%thread-nanosecond)\n" +
               "Library: (srfi 19)\n" +
               "Description: Internal primitive. Returns current thread CPU time as a pair (seconds . nanoseconds).\n" +
               "Example:\n" +
               "  (%thread-nanosecond) => (2 . 100000000)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        long nanoTime = ManagementFactory.getThreadMXBean().getCurrentThreadCpuTime();
        long seconds = nanoTime / 1_000_000_000L;
        long nanos = nanoTime % 1_000_000_000L;
        return new Pair(seconds, nanos);
    }
}
