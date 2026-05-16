package scheme.primitives;
import scheme.*;

public class PrimitiveJoinTimeoutExceptionP extends Primitive {
    @Override
    public String name() { return "join-timeout-exception?"; }

    @Override
    public String info() {
        return "Syntax: (join-timeout-exception? obj)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns #t if obj is a join-timeout exception.\n" +
               "Example:\n" +
               "  (guard (e ((join-timeout-exception? e) 'timeout)) (thread-join! t 0))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return isThreadException(arguments[0], SchemeThreadException.Kind.JOIN_TIMEOUT) ? Value.T : Value.F;
    }

    public static boolean isThreadException(Object obj, SchemeThreadException.Kind kind) {
        if (obj instanceof ErrorObject) {
            ErrorObject eo = (ErrorObject) obj;
            if (eo.irritants.length > 0 && eo.irritants[0] instanceof NativeValue) {
                NativeValue nv = (NativeValue) eo.irritants[0];
                if (nv.value instanceof SchemeThreadException)
                    return ((SchemeThreadException) nv.value).kind == kind;
            }
        }
        if (obj instanceof NativeValue) {
            NativeValue nv = (NativeValue) obj;
            if (nv.value instanceof SchemeThreadException)
                return ((SchemeThreadException) nv.value).kind == kind;
        }
        return false;
    }

    public static SchemeThreadException getThreadException(Object obj) {
        if (obj instanceof ErrorObject) {
            ErrorObject eo = (ErrorObject) obj;
            if (eo.irritants.length > 0 && eo.irritants[0] instanceof NativeValue) {
                NativeValue nv = (NativeValue) eo.irritants[0];
                if (nv.value instanceof SchemeThreadException)
                    return (SchemeThreadException) nv.value;
            }
        }
        if (obj instanceof NativeValue) {
            NativeValue nv = (NativeValue) obj;
            if (nv.value instanceof SchemeThreadException)
                return (SchemeThreadException) nv.value;
        }
        return null;
    }
}
