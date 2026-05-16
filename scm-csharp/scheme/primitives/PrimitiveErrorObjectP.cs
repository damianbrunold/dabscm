namespace scheme;

public class PrimitiveErrorObjectP : Primitive
{
    public override string Name() => "error-object?";
    public override string Info() =>
        "Syntax: (error-object? obj)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns #t if obj is an error object (as raised by error), otherwise returns #f.\n" +
        "Example:\n" +
        "  (guard (e (#t (error-object? e)))\n" +
        "    (error \"oops\")) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return arguments[0] is ErrorObject ? Value.T : Value.F;
    }
}
