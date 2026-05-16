namespace scheme;

public class PrimitiveErrorObjectIrritants : Primitive
{
    public override string Name() => "error-object-irritants";
    public override string Info() =>
        "Syntax: (error-object-irritants error-object)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns the list of irritants (extra objects) of the given error object.\n" +
        "Example:\n" +
        "  (guard (e (#t (error-object-irritants e)))\n" +
        "    (error \"bad value\" 42)) => (42)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var e = arguments[0] as ErrorObject
            ?? throw new SchemeError(pos, "error-object-irritants: not an error object");
        return Pair.List(e.Irritants);
    }
}
