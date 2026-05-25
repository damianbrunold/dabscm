namespace scheme;

public class PrimitiveStringAppend : Primitive
{
    public override string Name()
    {
        return "string-append";
    }

    public override string Info()
    {
        return
            "Syntax: (string-append string ...)\n" +
            "Library: (scheme base) (srfi 13)\n" +
            "Description: Returns a newly allocated string whose characters are the concatenation of the characters in the given strings.\n" +
            "Example:\n" +
            "  (string-append \"foo\" \"bar\") => \"foobar\"\n" +
            "  (string-append \"a\" \"b\" \"c\") => \"abc\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        int total = 0;
        char[][] parts = new char[arguments.Length][];
        for (int i = 0; i < arguments.Length; i++)
        {
            char[] part = Value.AsString(arguments[i]);
            parts[i] = part;
            total += part.Length;
        }
        char[] result = new char[total];
        int offset = 0;
        for (int i = 0; i < parts.Length; i++)
        {
            char[] part = parts[i];
            Array.Copy(part, 0, result, offset, part.Length);
            offset += part.Length;
        }
        return result;
    }
}
