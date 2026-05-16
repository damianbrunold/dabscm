namespace scheme;

public class PrimitiveErrorObjectMessage : Primitive
{
    public override string Name() => "error-object-message";
    public override string Info() =>
        "Syntax: (error-object-message error-object)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns the message string of the given error object.\n" +
        "Example:\n" +
        "  (guard (e (#t (error-object-message e)))\n" +
        "    (error \"bad value\" 42)) => \"bad value\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var e = arguments[0] as ErrorObject
            ?? throw new SchemeError(pos, "error-object-message: not an error object");
        return e.Message.ToCharArray();
    }
}
