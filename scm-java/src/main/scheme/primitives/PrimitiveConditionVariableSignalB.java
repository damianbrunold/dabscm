package scheme.primitives;
import scheme.*;

public class PrimitiveConditionVariableSignalB extends Primitive {
    @Override
    public String name() { return "condition-variable-signal!"; }

    @Override
    public String info() {
        return "Syntax: (condition-variable-signal! cv)\n" +
               "Library: (srfi 18)\n" +
               "Description: Signals the condition variable, waking one waiting thread.\n" +
               "Example:\n" +
               "  (condition-variable-signal! cv)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeConditionVariable cv = (SchemeConditionVariable) Value.asNativeValue(arguments[0]).value;
        cv.signal();
        return Value.NIL;
    }
}
