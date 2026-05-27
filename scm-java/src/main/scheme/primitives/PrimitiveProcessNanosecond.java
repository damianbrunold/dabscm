package scheme.primitives;

import scheme.Pair;
import scheme.Primitive;
import scheme.SourcePos;

import java.lang.management.ManagementFactory;

public class PrimitiveProcessNanosecond extends Primitive {
    @Override
    public String name() {
        return "%process-nanosecond";
    }

    @Override
    public String info() {
        return "Syntax: (%process-nanosecond)\n" +
               "Library: (scm core)\n" +
               "Description: Internal primitive. Returns process CPU time as a pair (seconds . nanoseconds).\n" +
               "Example:\n" +
               "  (%process-nanosecond) => (5 . 230000000)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        long nanos = 0;
        var bean = ManagementFactory.getThreadMXBean();
        for (long id : bean.getAllThreadIds()) {
            long cpu = bean.getThreadCpuTime(id);
            if (cpu > 0) nanos += cpu;
        }
        long seconds = nanos / 1_000_000_000L;
        nanos = nanos % 1_000_000_000L;
        return new Pair(seconds, nanos);
    }
}
