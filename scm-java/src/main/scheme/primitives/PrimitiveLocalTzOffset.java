package scheme.primitives;

import scheme.Primitive;
import scheme.SourcePos;

public class PrimitiveLocalTzOffset extends Primitive {
    @Override
    public String name() {
        return "%local-tz-offset";
    }

    @Override
    public String info() {
        return "Syntax: (%local-tz-offset)\n" +
               "Library: (srfi 19)\n" +
               "Description: Internal primitive. Returns the local timezone offset from UTC in seconds.\n" +
               "Example:\n" +
               "  (%local-tz-offset) => 3600  ; UTC+1";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return (long) java.util.TimeZone.getDefault().getOffset(System.currentTimeMillis()) / 1000;
    }
}
