package scheme.primitives;
import scheme.*;

public class PrimitiveMutexState extends Primitive {
    @Override
    public String name() { return "mutex-state"; }

    @Override
    public String info() {
        return "Syntax: (mutex-state mutex)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns the state of the mutex: the symbol abandoned, " +
               "not-owned, not-abandoned, or the owning thread object.\n" +
               "Example:\n" +
               "  (mutex-state (make-mutex)) => not-abandoned";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeMutex m = (SchemeMutex) Value.asNativeValue(arguments[0]).value;
        if (m.abandoned) return Value.intern("abandoned");
        if (m.locked && m.owner != null) return new NativeValue(m.owner);
        if (m.locked && m.owner == null) return Value.intern("not-owned");
        return Value.intern("not-abandoned");
    }
}
