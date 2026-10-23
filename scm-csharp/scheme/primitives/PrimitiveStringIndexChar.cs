namespace scheme;

public class PrimitiveStringIndexChar : Primitive
{
    public override string Name()
    {
        return "%string-index-char";
    }

    public override string Info()
    {
        return
            "Syntax: (%string-index-char s char)\n" +
            "Library: (srfi 13)\n" +
            "Description: Returns the index of the first occurrence of char in s, or #f. The fast path of string-index for a char without start/end.\n" +
            "Example:\n" +
            "  (%string-index-char \"hello\" #\\l) => 2";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        char[] s = Value.AsString(arguments[0]);
        char c = Value.AsChar(arguments[1]);
        for (int i = 0; i < s.Length; i++)
            if (s[i] == c) return (long)i;
        return false;
    }
}
