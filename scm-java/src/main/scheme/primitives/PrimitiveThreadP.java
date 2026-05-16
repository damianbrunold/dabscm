package scheme.primitives;
import scheme.*;

public class PrimitiveThreadP extends Primitive {
    @Override
    public String name() { return "thread?"; }

    @Override
    public String info() {
        return "Syntax: (thread? x)\n" +
               "Library: (srfi 18)\n" +
               "Description: Returns #t if x is a thread object.\n" +
               "Example:\n" +
               "  (thread? (make-thread (lambda () 1))) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        return Value.isNativeValue(arguments[0]) && Value.asNativeValue(arguments[0]).value instanceof SchemeThread
            ? Value.T : Value.F;
    }
}
