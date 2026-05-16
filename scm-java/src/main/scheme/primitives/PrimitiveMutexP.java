package scheme.primitives;
import scheme.*;

public class PrimitiveMutexP extends Primitive {
    @Override
    public String name() { return "mutex?"; }

    @Override
    public String info() {
        return "Syntax: (mutex? x)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns #t if x is a mutex object.\n" +
               "Example:\n" +
               "  (mutex? (make-mutex)) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isNativeValue(arguments[0]) && Value.asNativeValue(arguments[0]).value instanceof SchemeMutex
            ? Value.T : Value.F;
    }
}
