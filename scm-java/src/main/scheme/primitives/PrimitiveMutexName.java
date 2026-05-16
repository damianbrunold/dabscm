package scheme.primitives;
import scheme.*;

public class PrimitiveMutexName extends Primitive {
    @Override
    public String name() { return "mutex-name"; }

    @Override
    public String info() {
        return "Syntax: (mutex-name mutex)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns the name of the mutex.\n" +
               "Example:\n" +
               "  (mutex-name (make-mutex 'my-mutex)) => my-mutex";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeMutex m = (SchemeMutex) Value.asNativeValue(arguments[0]).value;
        return m.name;
    }
}
