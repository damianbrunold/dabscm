package scheme.primitives;
import scheme.*;

public class PrimitiveCurrentThread extends Primitive {
    @Override
    public String name() { return "current-thread"; }

    @Override
    public String info() {
        return "Syntax: (current-thread)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns the current thread object.\n" +
               "Example:\n" +
               "  (thread? (current-thread)) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        SchemeThread t = SchemeThread.currentThread.get();
        if (t == null) throw new SchemeError(pos, "current-thread: no current thread");
        return new NativeValue(t);
    }
}
