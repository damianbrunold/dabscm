package scheme.primitives;

import scheme.*;

public class PrimitiveTerminalByteReadyP extends Primitive {
    @Override
    public String name() {
        return "terminal-byte-ready?";
    }

    @Override
    public String info() {
        return "Syntax: (terminal-byte-ready? [timeout-ms])\n" +
               "Library: (scm terminal)\n" +
               "Description: Returns #t if a byte is available for reading from\n" +
               "standard input without blocking, #f otherwise. With timeout-ms,\n" +
               "waits up to that many milliseconds for a byte to arrive.\n" +
               "Intended for use in raw terminal mode to detect multi-byte\n" +
               "escape sequences.\n" +
               "Example:\n" +
               "  (terminal-byte-ready?) => #f\n" +
               "  (terminal-byte-ready? 50) => #t  ; a key arrived within 50 ms";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        long timeout = arguments.length > 0 ? IntegerMath.toLong(arguments[0]) : 0;
        try {
            if (System.in.available() > 0) return true;
            if (timeout <= 0) return false;
            // System.in offers no select(); poll available() with short sleeps.
            long deadline = System.nanoTime() + timeout * 1_000_000L;
            while (true) {
                long remaining = (deadline - System.nanoTime()) / 1_000_000L;
                if (remaining <= 0) return System.in.available() > 0;
                Thread.sleep(Math.min(remaining, 3));
                if (System.in.available() > 0) return true;
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return false;
        } catch (Exception e) {
            return false;
        }
    }
}
