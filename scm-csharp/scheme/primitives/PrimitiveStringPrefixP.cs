namespace scheme;

public class PrimitiveStringPrefixP : Primitive
{
    public override string Name()
    {
        return "string-prefix?";
    }

    public override string Info()
    {
        return
            "Syntax: (string-prefix? prefix s)\n" +
            "Library: (srfi 13)\n" +
            "Description: Returns #t if prefix is a prefix of s, otherwise returns #f.\n" +
            "Example:\n" +
            "  (string-prefix? \"hel\" \"hello\") => #t\n" +
            "  (string-prefix? \"world\" \"hello\") => #f";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        char[] prefix = Value.AsString(arguments[0]);
        char[] str = Value.AsString(arguments[1]);
        if (prefix.Length > str.Length)
        {
            return false;
        }
        var i = 0;
        while (i < prefix.Length)
        {
            if (str[i] != prefix[i]) return false;
            i++;
        }
        return true;
    }
}
