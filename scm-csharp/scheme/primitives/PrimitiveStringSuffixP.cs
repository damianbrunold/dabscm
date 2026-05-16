namespace scheme;

public class PrimitiveStringSuffixP : Primitive
{
    public override string Name()
    {
        return "string-suffix?";
    }

    public override string Info()
    {
        return
            "Syntax: (string-suffix? suffix s)\n" +
            "Library: (srfi 13)\n" +
            "Description: Returns #t if suffix is a suffix of s, otherwise returns #f.\n" +
            "Example:\n" +
            "  (string-suffix? \"lo\" \"hello\") => #t\n" +
            "  (string-suffix? \"hi\" \"hello\") => #f";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        char[] suffix = Value.AsString(arguments[0]);
        char[] str = Value.AsString(arguments[1]);
        if (suffix.Length > str.Length)
        {
            return false;
        }
        var i = suffix.Length - 1;
        var j = str.Length - 1;
        while (i >= 0)
        {
            if (str[j] != suffix[i]) return false;
            i--;
            j--;
        }
        return true;
    }
}
