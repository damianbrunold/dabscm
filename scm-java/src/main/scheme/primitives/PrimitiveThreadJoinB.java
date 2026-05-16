package scheme.primitives;
import scheme.*;

public class PrimitiveThreadJoinB extends Primitive {
    @Override
    public String name() { return "thread-join!"; }

    @Override
    public String info() {
        return "Syntax: (thread-join! thread [timeout [timeout-val]])\n" +
               "Library: (srfi 18)\n" +
               "Description: Waits for thread to terminate. Returns the thread's result value.\n" +
               "  If timeout is given and reached, returns timeout-val or raises a\n" +
               "  join-timeout-exception. If the thread terminated with an uncaught exception,\n" +
               "  raises an uncaught-exception.\n" +
               "Example:\n" +
               "  (thread-join! (thread-start! (make-thread (lambda () 42)))) => 42";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        SchemeThread t = (SchemeThread) Value.asNativeValue(arguments[0]).value;

        boolean hasTimeout = arguments.length >= 2 && arguments[1] != Value.F;
        long timeoutMs = -1; // -1 means infinite

        if (hasTimeout) {
            double seconds;
            if (Value.isReal(arguments[1])) {
                seconds = Value.asReal(arguments[1]);
            } else if (Value.isInteger(arguments[1])) {
                seconds = (double) IntegerMath.toLong(arguments[1]);
            } else {
                throw new SchemeError(pos, "thread-join!: invalid timeout ~s", arguments[1]);
            }
            timeoutMs = seconds <= 0 ? 0 : (long)(seconds * 1000);
        }

        boolean completed;
        if (t.thread != null) {
            try {
                if (timeoutMs < 0) {
                    t.thread.join();
                    completed = true;
                } else {
                    t.thread.join(timeoutMs);
                    completed = !t.thread.isAlive();
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                completed = false;
            }
        } else {
            completed = t.state == SchemeThread.State.TERMINATED;
        }

        if (!completed) {
            if (arguments.length >= 3)
                return arguments[2];
            throw new SchemeError(pos, new ErrorObject("join-timeout-exception",
                new Object[] { new NativeValue(new SchemeThreadException(SchemeThreadException.Kind.JOIN_TIMEOUT)) }));
        }

        if (t.exception != null) {
            SchemeError wrapper = new SchemeError(pos, new ErrorObject("uncaught-exception",
                new Object[] { new NativeValue(new SchemeThreadException(SchemeThreadException.Kind.UNCAUGHT, t.exception)) }));
            wrapper.parent = t.originalError;
            throw wrapper;
        }

        if (t.terminated) {
            throw new SchemeError(pos, new ErrorObject("terminated-thread-exception",
                new Object[] { new NativeValue(new SchemeThreadException(SchemeThreadException.Kind.TERMINATED_THREAD)) }));
        }

        return t.result;
    }
}
