namespace scheme;

public class PrimitiveMutexSpecific : Primitive
{
    public override string Name() => "mutex-specific";

    public override string Info() =>
        "Syntax: (mutex-specific mutex)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns the mutex-specific data associated with the mutex.\n" +
        "Example:\n" +
        "  (mutex-specific (make-mutex))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeMutex m = (SchemeMutex) Value.AsNativeValue(arguments[0]).value;
        return m.specific;
    }
}
