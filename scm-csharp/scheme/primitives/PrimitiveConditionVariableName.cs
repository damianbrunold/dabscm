namespace scheme;

public class PrimitiveConditionVariableName : Primitive
{
    public override string Name() => "condition-variable-name";

    public override string Info() =>
        "Syntax: (condition-variable-name cv)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns the name of the condition variable.\n" +
        "Example:\n" +
        "  (condition-variable-name (make-condition-variable 'my-cv)) => my-cv";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        SchemeConditionVariable cv = (SchemeConditionVariable) Value.AsNativeValue(arguments[0]).value;
        return cv.name;
    }
}
