package scheme.primitives;
import scheme.*;

public class PrimitiveTerminatedThreadExceptionP extends Primitive {
    @Override
    public String name() { return "terminated-thread-exception?"; }

    @Override
    public String info() {
        return "Syntax: (terminated-thread-exception? obj)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns #t if obj is a terminated-thread exception.\n" +
               "Example:\n" +
               "  (terminated-thread-exception? exn)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return PrimitiveJoinTimeoutExceptionP.isThreadException(
            arguments[0], SchemeThreadException.Kind.TERMINATED_THREAD) ? Value.T : Value.F;
    }
}
