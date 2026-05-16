package scheme.primitives;
import scheme.*;

public class PrimitiveConditionVariableName extends Primitive {
    @Override
    public String name() { return "condition-variable-name"; }

    @Override
    public String info() {
        return "Syntax: (condition-variable-name cv)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns the name of the condition variable.\n" +
               "Example:\n" +
               "  (condition-variable-name (make-condition-variable 'cv)) => cv";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeConditionVariable cv = (SchemeConditionVariable) Value.asNativeValue(arguments[0]).value;
        return cv.name;
    }
}
