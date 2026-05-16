package scheme.primitives;
import scheme.*;

public class PrimitiveMakeThread extends Primitive {
    private Modules modules;

    public PrimitiveMakeThread(Modules modules) { this.modules = modules; }

    @Override
    public String name() { return "make-thread"; }

    @Override
    public String info() {
        return "Syntax: (make-thread thunk [name])\n" +
               "Library: (srfi 18)\n" +
               "Description: Creates a new thread that will run thunk when started. " +
               "The thread is not started until thread-start! is called. " +
               "An optional name can be provided. " +
               "Note: continuations captured in one thread must not be invoked in another.\n" +
               "Example:\n" +
               "  (thread-join! (thread-start! (make-thread (lambda () (+ 1 2))))) => 3";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        Lambda lambda = Value.asLambda(arguments[0]);
        SchemeThread t = new SchemeThread(lambda, modules);
        if (arguments.length > 1) t.name = arguments[1];
        return new NativeValue(t);
    }
}
