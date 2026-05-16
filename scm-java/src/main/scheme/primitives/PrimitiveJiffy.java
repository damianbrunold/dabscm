package scheme.primitives;

import scheme.Primitive;
import scheme.SourcePos;

public class PrimitiveJiffy extends Primitive {
    @Override
    public String name() {
        return "%jiffy";
    }

    @Override
    public String info() {
        return "Syntax: (%jiffy)\n" +
               "Library: (scheme time)\n" +
               "Description: Internal primitive. Returns the number of microseconds elapsed since the Unix epoch (1970-01-01 00:00:00 UTC).\n" +
               "Example:\n" +
               "  (%jiffy) => 1700000000000000";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        var now = java.time.Instant.now();
        return now.getEpochSecond() * 1_000_000L + now.getNano() / 1000;
    }
}
