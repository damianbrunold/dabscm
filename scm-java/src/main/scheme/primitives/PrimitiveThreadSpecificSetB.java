package scheme.primitives;
import scheme.*;

public class PrimitiveThreadSpecificSetB extends Primitive {
    @Override
    public String name() { return "thread-specific-set!"; }

    @Override
    public String info() {
        return "Syntax: (thread-specific-set! thread obj)\n" +
               "Library: (srfi 18)\n" +
               "Description: Sets the thread-specific data of the thread to obj.\n" +
               "Example:\n" +
               "  (thread-specific-set! (current-thread) 42)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        SchemeThread t = (SchemeThread) Value.asNativeValue(arguments[0]).value;
        t.specific = arguments[1];
        return Value.NIL;
    }
}
