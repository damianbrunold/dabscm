namespace scheme;

public class PrimitiveConditionVariableSpecific : Primitive
{
    public override string Name() => "condition-variable-specific";

    public override string Info() =>
        "Syntax: (condition-variable-specific cv)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns the condition-variable-specific data.\n" +
        "Example:\n" +
        "  (condition-variable-specific cv)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeConditionVariable cv = (SchemeConditionVariable) Value.AsNativeValue(arguments[0]).value;
        return cv.specific;
    }
}
