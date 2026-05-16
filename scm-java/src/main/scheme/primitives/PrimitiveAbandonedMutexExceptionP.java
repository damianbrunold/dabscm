package scheme.primitives;
import scheme.*;

public class PrimitiveAbandonedMutexExceptionP extends Primitive {
    @Override
    public String name() { return "abandoned-mutex-exception?"; }

    @Override
    public String info() {
        return "Syntax: (abandoned-mutex-exception? obj)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns #t if obj is an abandoned-mutex exception.\n" +
               "Example:\n" +
               "  (abandoned-mutex-exception? exn)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return PrimitiveJoinTimeoutExceptionP.isThreadException(
            arguments[0], SchemeThreadException.Kind.ABANDONED_MUTEX) ? Value.T : Value.F;
    }
}
