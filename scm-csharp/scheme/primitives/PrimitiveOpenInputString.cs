namespace scheme;

public class PrimitiveOpenInputString : Primitive
{
    public override string Name()
    {
        return "open-input-string";
    }

    public override string Info()
    {
        return
            "Syntax: (open-input-string string)\n" +
            "Library: (scheme base)\n" +
            "Description: Takes a string and returns a textual input port that delivers characters from the string.\n" +
            "Example:\n" +
            "  (define p (open-input-string \"hello\"))\n" +
            "  (read-char p) => #\\h";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        string text = new String(Value.AsString(arguments[0]));
        return new TextStream(new StringReader(text), "{string}");
    }
}
