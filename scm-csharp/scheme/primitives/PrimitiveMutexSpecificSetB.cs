namespace scheme;

public class PrimitiveMutexSpecificSetB : Primitive
{
    public override string Name() => "mutex-specific-set!";

    public override string Info() =>
        "Syntax: (mutex-specific-set! mutex obj)\n" +
        "Library: (srfi 18)\n" +
        "Description: Sets the mutex-specific data associated with the mutex.\n" +
        "Example:\n" +
        "  (mutex-specific-set! m 'data)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        SchemeMutex m = (SchemeMutex) Value.AsNativeValue(arguments[0]).value;
        m.specific = arguments[1];
        return Value.NIL;
    }
}
