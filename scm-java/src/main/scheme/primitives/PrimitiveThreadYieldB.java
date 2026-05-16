package scheme.primitives;
import scheme.*;

public class PrimitiveThreadYieldB extends Primitive {
    @Override
    public String name() { return "thread-yield!"; }

    @Override
    public String info() {
        return "Syntax: (thread-yield!)\n" +
               "Library: (srfi 18)\n" +
               "Description: Causes the current thread to yield the processor.\n" +
               "Example:\n" +
               "  (thread-yield!)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        Thread.yield();
        return Value.NIL;
    }
}
