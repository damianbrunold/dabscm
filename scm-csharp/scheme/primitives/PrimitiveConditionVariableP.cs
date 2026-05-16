namespace scheme;

public class PrimitiveConditionVariableP : Primitive
{
    public override string Name() => "condition-variable?";

    public override string Info() =>
        "Syntax: (condition-variable? obj)\n" +
        "Library: (srfi 18)\n" +
        "Description: Returns #t if obj is a condition variable, #f otherwise.\n" +
        "Example:\n" +
        "  (condition-variable? (make-condition-variable)) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return (arguments[0] is NativeValue nv && nv.value is SchemeConditionVariable) ? Value.T : Value.F;
    }
}
