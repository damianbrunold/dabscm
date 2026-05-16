namespace scheme;

public class PrimitiveConditionVariableBroadcastB : Primitive
{
    public override string Name() => "condition-variable-broadcast!";

    public override string Info() =>
        "Syntax: (condition-variable-broadcast! cv)\n" +
        "Library: (srfi 18)\n" +
        "Description: Wakes up all threads waiting on the condition variable.\n" +
        "Example:\n" +
        "  (condition-variable-broadcast! cv)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeConditionVariable cv = (SchemeConditionVariable) Value.AsNativeValue(arguments[0]).value;
        cv.Broadcast();
        return Value.NIL;
    }
}
