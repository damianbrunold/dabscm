package scheme.primitives;
import scheme.*;

public class PrimitiveConditionVariableSpecificSetB extends Primitive {
    @Override
    public String name() { return "condition-variable-specific-set!"; }

    @Override
    public String info() {
        return "Syntax: (condition-variable-specific-set! cv obj)\n" +
               "Library: (srfi 18)\n" +
               "Description: Sets the condition-variable-specific data to obj.\n" +
               "Example:\n" +
               "  (condition-variable-specific-set! cv 42)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        SchemeConditionVariable cv = (SchemeConditionVariable) Value.asNativeValue(arguments[0]).value;
        cv.specific = arguments[1];
        return Value.NIL;
    }
}
