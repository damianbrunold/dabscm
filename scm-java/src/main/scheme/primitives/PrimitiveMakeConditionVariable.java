package scheme.primitives;
import scheme.*;

public class PrimitiveMakeConditionVariable extends Primitive {
    @Override
    public String name() { return "make-condition-variable"; }

    @Override
    public String info() {
        return "Syntax: (make-condition-variable [name])\n" +
               "Library: (srfi 18)\n" +
               "Description: Creates a new condition variable, optionally with a name.\n" +
               "Example:\n" +
               "  (make-condition-variable 'my-cv)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        SchemeConditionVariable cv = new SchemeConditionVariable();
        if (arguments.length > 0) cv.name = arguments[0];
        return new NativeValue(cv);
    }
}
