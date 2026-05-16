package scheme.primitives;
import scheme.*;

public class PrimitiveMutexSpecific extends Primitive {
    @Override
    public String name() { return "mutex-specific"; }

    @Override
    public String info() {
        return "Syntax: (mutex-specific mutex)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns the mutex-specific data of the mutex.\n" +
               "Example:\n" +
               "  (mutex-specific (make-mutex)) => ()";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeMutex m = (SchemeMutex) Value.asNativeValue(arguments[0]).value;
        return m.specific;
    }
}
