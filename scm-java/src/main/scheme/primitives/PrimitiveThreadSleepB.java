package scheme.primitives;
import scheme.*;

public class PrimitiveThreadSleepB extends Primitive {
    @Override
    public String name() { return "thread-sleep!"; }

    @Override
    public String info() {
        return "Syntax: (thread-sleep! timeout)\n" +
               "Library: (srfi 18)\n" +
               "Description: Causes the current thread to sleep until the timeout. " +
               "Timeout can be a time object, an integer (seconds), or a real (seconds).\n" +
               "Example:\n" +
               "  (thread-sleep! 1)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        long ms;
        if (Value.isInteger(arguments[0])) {
            ms = IntegerMath.toLong(arguments[0]) * 1000;
        } else if (Value.isReal(arguments[0])) {
            ms = (long) (Value.asReal(arguments[0]) * 1000);
        } else {
            throw new SchemeError(pos, "thread-sleep!: invalid timeout ~s", arguments[0]);
        }
        if (ms > 0) {
            try {
                Thread.sleep(ms);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
        return Value.NIL;
    }
}
