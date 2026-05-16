namespace scheme;

public class PrimitiveError : Primitive
{
    public override string Name()
    {
        return "error";
    }

    public override string Info()
    {
        return
            "Syntax: (error message obj ...) (error who message obj ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Raises an error. In R7RS form, message is a string and obj ... are irritants. In SRFI-23 form, who is a symbol identifying the caller.\n" +
            "Example:\n" +
            "  (error \"out of range\" 42)\n" +
            "  (error 'my-proc \"value out of range\" 42)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, -1);
        string message;
        object[] irritants;
        if (Value.IsSymbol(arguments[0])) {
            // SRFI-23: (error who message irritant ...)
            CheckArgs(pos, arguments, 2, -1);
            string who = Value.AsSymbol(arguments[0]);
            message = who + ": " + new string(Value.AsString(arguments[1]));
            irritants = arguments.Skip(2).ToArray();
        } else {
            // R7RS: (error message irritant ...)
            message = new string(Value.AsString(arguments[0]));
            irritants = arguments.Skip(1).ToArray();
        }
        var errorObj = new ErrorObject(message, irritants);
        throw new SchemeError(pos, errorObj);
    }
}
