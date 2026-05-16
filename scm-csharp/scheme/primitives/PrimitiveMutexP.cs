namespace scheme;

public class PrimitiveMutexP : Primitive
{
    public override string Name() => "mutex?";

    public override string Info() =>
        "Syntax: (mutex? x)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns #t if x is a mutex object.\n" +
        "Example:\n" +
        "  (mutex? (make-mutex)) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsNativeValue(arguments[0]) && Value.AsNativeValue(arguments[0]).value is SchemeMutex
            ? Value.T : Value.F;
    }
}
