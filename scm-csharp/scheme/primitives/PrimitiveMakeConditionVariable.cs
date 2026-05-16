namespace scheme;

public class PrimitiveMakeConditionVariable : Primitive
{
    public override string Name() => "make-condition-variable";

    public override string Info() =>
        "Syntax: (make-condition-variable [name])\n" +
        "Library: (srfi 18)\n" +
        "Description: Creates a new condition variable, optionally with the given name.\n" +
        "Example:\n" +
        "  (define cv (make-condition-variable 'my-cv))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);
        SchemeConditionVariable cv = new SchemeConditionVariable();
        if (arguments.Length > 0)
            cv.name = arguments[0];
        return new NativeValue(cv);
    }
}
