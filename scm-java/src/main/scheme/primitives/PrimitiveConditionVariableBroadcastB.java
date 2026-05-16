package scheme.primitives;
import scheme.*;

public class PrimitiveConditionVariableBroadcastB extends Primitive {
    @Override
    public String name() { return "condition-variable-broadcast!"; }

    @Override
    public String info() {
        return "Syntax: (condition-variable-broadcast! cv)\n" +
               "Library: (srfi 18)\n" +
               "Description: Broadcasts the condition variable, waking all waiting threads.\n" +
               "Example:\n" +
               "  (condition-variable-broadcast! cv)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeConditionVariable cv = (SchemeConditionVariable) Value.asNativeValue(arguments[0]).value;
        cv.broadcast();
        return Value.NIL;
    }
}
