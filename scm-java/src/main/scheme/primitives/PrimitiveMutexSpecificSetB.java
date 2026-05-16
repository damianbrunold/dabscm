package scheme.primitives;
import scheme.*;

public class PrimitiveMutexSpecificSetB extends Primitive {
    @Override
    public String name() { return "mutex-specific-set!"; }

    @Override
    public String info() {
        return "Syntax: (mutex-specific-set! mutex obj)\n" +
               "Library: (srfi 18)\n" +
               "Description: Sets the mutex-specific data of the mutex to obj.\n" +
               "Example:\n" +
               "  (mutex-specific-set! (make-mutex) 42)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        SchemeMutex m = (SchemeMutex) Value.asNativeValue(arguments[0]).value;
        m.specific = arguments[1];
        return Value.NIL;
    }
}
