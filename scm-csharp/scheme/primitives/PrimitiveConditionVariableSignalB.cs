namespace scheme;

public class PrimitiveConditionVariableSignalB : Primitive
{
    public override string Name() => "condition-variable-signal!";

    public override string Info() =>
        "Syntax: (condition-variable-signal! cv)\n" +
        "Library: (srfi 18)\n" +
        "Description: Wakes up one thread waiting on the condition variable.\n" +
        "Example:\n" +
        "  (condition-variable-signal! cv)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeConditionVariable cv = (SchemeConditionVariable) Value.AsNativeValue(arguments[0]).value;
        cv.Signal();
        return Value.NIL;
    }
}
