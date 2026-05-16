package scheme.primitives;
import scheme.*;

public class PrimitiveThreadSpecific extends Primitive {
    @Override
    public String name() { return "thread-specific"; }

    @Override
    public String info() {
        return "Syntax: (thread-specific thread)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns the thread-specific data of the thread.\n" +
               "Example:\n" +
               "  (thread-specific (current-thread)) => ()";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeThread t = (SchemeThread) Value.asNativeValue(arguments[0]).value;
        return t.specific;
    }
}
