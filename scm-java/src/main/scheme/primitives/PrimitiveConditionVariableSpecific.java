package scheme.primitives;
import scheme.*;

public class PrimitiveConditionVariableSpecific extends Primitive {
    @Override
    public String name() { return "condition-variable-specific"; }

    @Override
    public String info() {
        return "Syntax: (condition-variable-specific cv)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns the condition-variable-specific data.\n" +
               "Example:\n" +
               "  (condition-variable-specific (make-condition-variable)) => ()";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeConditionVariable cv = (SchemeConditionVariable) Value.asNativeValue(arguments[0]).value;
        return cv.specific;
    }
}
