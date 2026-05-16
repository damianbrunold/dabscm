package scheme.primitives;
import scheme.*;

public class PrimitiveConditionVariableP extends Primitive {
    @Override
    public String name() { return "condition-variable?"; }

    @Override
    public String info() {
        return "Syntax: (condition-variable? obj)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns #t if obj is a condition variable.\n" +
               "Example:\n" +
               "  (condition-variable? (make-condition-variable)) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return (arguments[0] instanceof NativeValue && ((NativeValue) arguments[0]).value instanceof SchemeConditionVariable)
            ? Value.T : Value.F;
    }
}
