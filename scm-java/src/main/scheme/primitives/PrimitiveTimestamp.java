package scheme.primitives;

import scheme.*;

public class PrimitiveTimestamp extends Primitive {
    @Override
    public String name() {
        return "timestamp";
    }

    @Override
    public String info() {
        return "Syntax: (timestamp)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the current time as the number of milliseconds since the epoch (January 1, year 1).\n" +
               "Example:\n" +
               "  (timestamp) => 63850000000000";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return System.currentTimeMillis();
    }
}
