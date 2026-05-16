package scheme.primitives;
import scheme.*;
import java.util.concurrent.TimeUnit;

public class PrimitiveProcessWait extends Primitive {
    @Override
    public String name() { return "process-wait"; }

    @Override
    public String info() {
        return "Syntax: (process-wait handle [timeout-ms])\n" +
               "Library: (scm system)\n" +
               "Description: Waits for the process to exit. Without timeout-ms, blocks " +
               "until exit and returns the exit code as an integer. With timeout-ms, " +
               "waits at most that long; returns the exit code on exit, or #f if the " +
               "process is still running when the timeout elapses.\n" +
               "Example:\n" +
               "  (process-wait p)            => 0\n" +
               "  (process-wait p 5000)       => 0 or #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        SchemeProcess sp = (SchemeProcess) Value.asNativeValue(arguments[0]).value;
        try {
            if (arguments.length == 1) {
                int rc = sp.process.waitFor();
                return (long) rc;
            }
            int timeoutMs = IntegerMath.toInt(arguments[1]);
            boolean exited = sp.process.waitFor(timeoutMs, TimeUnit.MILLISECONDS);
            if (exited) return (long) sp.process.exitValue();
            return Value.F;
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
            return Value.F;
        }
    }
}
