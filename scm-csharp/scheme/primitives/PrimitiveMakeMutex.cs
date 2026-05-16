namespace scheme;

public class PrimitiveMakeMutex : Primitive
{
    public override string Name() => "make-mutex";

    public override string Info() =>
        "Syntax: (make-mutex [name])\n" +
        "Library: (srfi 18)\n" +
        "Description: Creates a new mutex (mutual exclusion lock), optionally with the given name.\n" +
        "Example:\n" +
        "  (define m (make-mutex 'my-mutex))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);
        SchemeMutex m = new SchemeMutex();
        if (arguments.Length > 0)
            m.name = arguments[0];
        return new NativeValue(m);
    }
}
