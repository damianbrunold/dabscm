package scheme.primitives;
import scheme.*;

public class PrimitiveThreadName extends Primitive {
    @Override
    public String name() { return "thread-name"; }

    @Override
    public String info() {
        return "Syntax: (thread-name thread)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns the name of the thread.\n" +
               "Example:\n" +
               "  (thread-name (make-thread (lambda () #t) 'my-thread)) => my-thread";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeThread t = (SchemeThread) Value.asNativeValue(arguments[0]).value;
        return t.name;
    }
}
