package scheme.primitives;
import scheme.*;
import java.util.concurrent.TimeUnit;

public class PrimitiveMutexUnlockB extends Primitive {
    @Override
    public String name() { return "mutex-unlock!"; }

    @Override
    public String info() {
        return "Syntax: (mutex-unlock! mutex [condition-variable [timeout]])\n" +
               "Library: (srfi 18)\n" +
               "Description: Unlocks the mutex. If a condition-variable is given, the current\n" +
               "  thread is blocked and added to the condition-variable's wait queue, and the\n" +
               "  mutex is atomically unlocked. Returns #t if the thread was signaled, #f if\n" +
               "  timed out.\n" +
               "Example:\n" +
               "  (mutex-unlock! m)\n" +
               "  (mutex-unlock! m cv 1.0)  ; unlock and wait on cv up to 1s";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        SchemeMutex m = (SchemeMutex) Value.asNativeValue(arguments[0]).value;

        m.lock.lock();
        try {
            m.locked = false;
            m.owner = null;
            m.condition.signalAll();
        } finally {
            m.lock.unlock();
        }

        if (arguments.length >= 2) {
            SchemeConditionVariable cv = (SchemeConditionVariable) Value.asNativeValue(arguments[1]).value;

            boolean hasTimeout = arguments.length >= 3 && arguments[2] != Value.F;
            long timeoutMs = -1;

            if (hasTimeout) {
                double seconds;
                if (Value.isReal(arguments[2])) {
                    seconds = Value.asReal(arguments[2]);
                } else if (Value.isInteger(arguments[2])) {
                    seconds = (double) IntegerMath.toLong(arguments[2]);
                } else {
                    throw new SchemeError(pos, "mutex-unlock!: invalid timeout ~s", arguments[2]);
                }
                timeoutMs = seconds <= 0 ? 0 : (long)(seconds * 1000);
            }

            try {
                if (timeoutMs < 0) {
                    cv.awaitUninterruptibly();
                    return Value.T;
                } else {
                    return cv.await(timeoutMs) ? Value.T : Value.F;
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return Value.F;
            }
        }

        return Value.T;
    }
}
