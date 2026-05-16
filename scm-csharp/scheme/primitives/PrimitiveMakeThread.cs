namespace scheme;

public class PrimitiveMakeThread : Primitive
{
    private Modules modules;

    public PrimitiveMakeThread(Modules modules) => this.modules = modules;

    public override string Name() => "make-thread";

    public override string Info() =>
        "Syntax: (make-thread thunk [name])\n" +
        "Library: (srfi 18)\n" +
        "Description: Creates a new thread that will run thunk when started. " +
        "The thread is not started until thread-start! is called. " +
        "An optional name can be provided. " +
        "Note: continuations captured in one thread must not be invoked in another.\n" +
        "Example:\n" +
        "  (thread-join! (thread-start! (make-thread (lambda () (+ 1 2))))) => 3";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        Lambda lambda = Value.AsLambda(arguments[0]);
        SchemeThread t = new SchemeThread(lambda, modules);
        if (arguments.Length > 1)
            t.name = arguments[1];
        return new NativeValue(t);
    }
}
