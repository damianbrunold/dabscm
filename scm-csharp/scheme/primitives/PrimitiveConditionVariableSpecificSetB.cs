namespace scheme;

public class PrimitiveConditionVariableSpecificSetB : Primitive
{
    public override string Name() => "condition-variable-specific-set!";

    public override string Info() =>
        "Syntax: (condition-variable-specific-set! cv obj)\n" +
        "Library: (srfi 18)\n" +
        "Description: Sets the condition-variable-specific data.\n" +
        "Example:\n" +
        "  (condition-variable-specific-set! cv 'data)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        SchemeConditionVariable cv = (SchemeConditionVariable) Value.AsNativeValue(arguments[0]).value;
        cv.specific = arguments[1];
        return Value.NIL;
    }
}
