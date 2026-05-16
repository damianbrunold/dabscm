namespace scheme;

public class PrimitiveMutexName : Primitive
{
    public override string Name() => "mutex-name";

    public override string Info() =>
        "Syntax: (mutex-name mutex)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns the name of the mutex.\n" +
        "Example:\n" +
        "  (mutex-name (make-mutex 'my-mutex)) => my-mutex";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeMutex m = (SchemeMutex) Value.AsNativeValue(arguments[0]).value;
        return m.name;
    }
}
