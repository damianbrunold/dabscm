namespace scheme;

public class PrimitiveMutexState : Primitive
{
    public override string Name() => "mutex-state";

    public override string Info() =>
        "Syntax: (mutex-state mutex)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns the state of the mutex: the symbol abandoned, " +
        "not-owned, not-abandoned, or the thread that owns it.\n" +
        "Example:\n" +
        "  (mutex-state (make-mutex)) => not-abandoned";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeMutex m = (SchemeMutex) Value.AsNativeValue(arguments[0]).value;
        if (m.abandoned)
            return Value.Intern("abandoned");
        if (m.locked && m.owner != null)
            return new NativeValue(m.owner);
        if (m.locked && m.owner == null)
            return Value.Intern("not-owned");
        return Value.Intern("not-abandoned");
    }
}
