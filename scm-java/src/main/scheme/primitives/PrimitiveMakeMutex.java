package scheme.primitives;
import scheme.*;

public class PrimitiveMakeMutex extends Primitive {
    @Override
    public String name() { return "make-mutex"; }

    @Override
    public String info() {
        return "Syntax: (make-mutex [name])\n" +
               "Library: (srfi 18)\n" +
               "Description: Creates a new mutex (mutual exclusion lock), optionally with a name.\n" +
               "Example:\n" +
               "  (define m (make-mutex 'my-mutex))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        SchemeMutex m = new SchemeMutex();
        if (arguments.length > 0) m.name = arguments[0];
        return new NativeValue(m);
    }
}
