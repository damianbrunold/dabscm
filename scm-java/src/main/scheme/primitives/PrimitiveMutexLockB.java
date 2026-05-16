package scheme.primitives;
import scheme.*;
import java.util.concurrent.TimeUnit;

public class PrimitiveMutexLockB extends Primitive {
    @Override
    public String name() { return "mutex-lock!"; }

    @Override
    public String info() {
        return "Syntax: (mutex-lock! mutex [timeout [thread]])\n" +
               "Library: (srfi 18)\n" +
               "Description: Locks the mutex. If already locked, blocks until available or timeout.\n" +
               "  Returns #t if locked successfully, #f if timed out. If the mutex was abandoned\n" +
               "  by a terminated thread, locks it but raises an abandoned-mutex-exception.\n" +
               "Example:\n" +
               "  (mutex-lock! m) => #t\n" +
               "  (mutex-lock! m 0.5) => #f  ; if not acquired within 0.5s";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        SchemeMutex m = (SchemeMutex) Value.asNativeValue(arguments[0]).value;

        boolean hasTimeout = arguments.length >= 2 && arguments[1] != Value.F;
        long timeoutMs = -1;

        if (hasTimeout) {
            double seconds;
            if (Value.isReal(arguments[1])) {
                seconds = Value.asReal(arguments[1]);
            } else if (Value.isInteger(arguments[1])) {
                seconds = (double) IntegerMath.toLong(arguments[1]);
            } else {
                throw new SchemeError(pos, "mutex-lock!: invalid timeout ~s", arguments[1]);
            }
            timeoutMs = seconds <= 0 ? 0 : (long)(seconds * 1000);
        }

        m.lock.lock();
        try {
            if (!m.locked) {
                m.locked = true;
                m.owner = SchemeThread.currentThread.get();
                boolean wasAbandoned = m.abandoned;
                m.abandoned = false;
                if (wasAbandoned)
                    throw new SchemeError(pos, new ErrorObject("abandoned-mutex-exception",
                        new Object[] { new NativeValue(new SchemeThreadException(SchemeThreadException.Kind.ABANDONED_MUTEX)) }));
                return Value.T;
            }

            if (timeoutMs == 0) return Value.F;

            try {
                if (timeoutMs < 0) {
                    while (m.locked)
                        m.condition.await();
                } else {
                    long deadline = System.currentTimeMillis() + timeoutMs;
                    while (m.locked) {
                        long remaining = deadline - System.currentTimeMillis();
                        if (remaining <= 0) return Value.F;
                        m.condition.await(remaining, TimeUnit.MILLISECONDS);
                    }
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return Value.F;
            }

            m.locked = true;
            m.owner = SchemeThread.currentThread.get();
            boolean wasAbandoned2 = m.abandoned;
            m.abandoned = false;
            if (wasAbandoned2)
                throw new SchemeError(pos, new ErrorObject("abandoned-mutex-exception",
                    new Object[] { new NativeValue(new SchemeThreadException(SchemeThreadException.Kind.ABANDONED_MUTEX)) }));
            return Value.T;
        } finally {
            m.lock.unlock();
        }
    }
}
