package scheme.primitives;
import scheme.*;

public class PrimitiveThreadTerminateB extends Primitive {
    @Override
    public String name() { return "thread-terminate!"; }

    @Override
    public String info() {
        return "Syntax: (thread-terminate! thread)\n" +
               "Library: (srfi 18)\n" +
               "Description: Terminates the given thread.\n" +
               "Example:\n" +
               "  (thread-terminate! thread)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeThread t = (SchemeThread) Value.asNativeValue(arguments[0]).value;
        t.terminated = true;
        t.state = SchemeThread.State.TERMINATED;
        if (t == SchemeThread.currentThread.get()) {
            throw new SchemeError(pos, "thread terminated");
        }
        return Value.NIL;
    }
}
