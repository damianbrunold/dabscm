namespace scheme;


public class PrimitiveOpenOutputString : Primitive
{
    public override string Name()
    {
        return "open-output-string";
    }

    public override string Info()
    {
        return
            "Syntax: (open-output-string)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns a textual output port that accumulates characters written to it. Use get-output-string to retrieve the accumulated string.\n" +
            "Example:\n" +
            "  (let ((p (open-output-string)))\n" +
            "    (write-char #\\h p)\n" +
            "    (get-output-string p)) => \"h\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return new TextOutputStream(new StringWriter());
    }
}
