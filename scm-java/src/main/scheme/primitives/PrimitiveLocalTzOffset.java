package scheme.primitives;

import scheme.IntegerMath;
import scheme.Primitive;
import scheme.SourcePos;

public class PrimitiveLocalTzOffset extends Primitive {
    @Override
    public String name() {
        return "%local-tz-offset";
    }

    @Override
    public String info() {
        return "Syntax: (%local-tz-offset [utc-seconds])\n" +
               "Library: (scm core)\n" +
               "Description: Internal primitive. Returns the local timezone offset from UTC in seconds,\n" +
               "  now or at the time utc-seconds (seconds since the epoch), so DST is taken into account.\n" +
               "Example:\n" +
               "  (%local-tz-offset) => 3600  ; UTC+1";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        long ms = System.currentTimeMillis();
        if (arguments.length > 0) {
            // clamped so that the milliseconds do not overflow
            long limit = Long.MAX_VALUE / 1000 - 1;
            ms = Math.max(-limit, Math.min(limit, IntegerMath.toLong(arguments[0]))) * 1000;
        }
        return (long) java.util.TimeZone.getDefault().getOffset(ms) / 1000;
    }
}
