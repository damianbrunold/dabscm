package scheme.primitives;
import scheme.*;

public class PrimitiveUncaughtExceptionReason extends Primitive {
    @Override
    public String name() { return "uncaught-exception-reason"; }

    @Override
    public String info() {
        return "Syntax: (uncaught-exception-reason exn)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns the original exception from an uncaught-exception object.\n" +
               "Example:\n" +
               "  (uncaught-exception-reason exn)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeThreadException te = PrimitiveJoinTimeoutExceptionP.getThreadException(arguments[0]);
        if (te != null && te.kind == SchemeThreadException.Kind.UNCAUGHT)
            return te.reason != null ? te.reason : Value.NIL;
        throw new SchemeError(pos, "uncaught-exception-reason: expected uncaught exception, got ~s", arguments[0]);
    }
}
