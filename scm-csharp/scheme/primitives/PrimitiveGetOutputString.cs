namespace scheme;

public class PrimitiveGetOutputString : Primitive
{
    public override string Name()
    {
        return "get-output-string";
    }

    public override string Info()
    {
        return
            "Syntax: (get-output-string port)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns a string consisting of the characters that have been output to the given string output port (created with open-output-string).\n" +
            "Example:\n" +
            "  (let ((p (open-output-string)))\n" +
            "    (write-char #\\A p)\n" +
            "    (get-output-string p)) => \"A\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var port = Value.AsOutputPort(arguments[0]);
        StringWriter writer;
        if (port is TextOutputStream tos)
            writer = (StringWriter) tos.Inner;
        else
            writer = (StringWriter) port;
        return writer.ToString().ToCharArray();
    }
}
