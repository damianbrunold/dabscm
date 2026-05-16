package scheme.primitives;
import scheme.*;

public class PrimitiveUncaughtExceptionP extends Primitive {
    @Override
    public String name() { return "uncaught-exception?"; }

    @Override
    public String info() {
        return "Syntax: (uncaught-exception? obj)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns #t if obj is an uncaught exception.\n" +
               "Example:\n" +
               "  (guard (e ((uncaught-exception? e) (uncaught-exception-reason e)))\n" +
               "    (thread-join! (thread-start! (make-thread (lambda () (error \"oops\"))))))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return PrimitiveJoinTimeoutExceptionP.isThreadException(
            arguments[0], SchemeThreadException.Kind.UNCAUGHT) ? Value.T : Value.F;
    }
}
