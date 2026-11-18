namespace scheme;

public class PrimitiveStringWidth : Primitive
{
    public override string Name()
    {
        return "string-width";
    }

    public override string Info()
    {
        return
            "Syntax: (string-width s [start [end]])\n" +
            "Library: (scm terminal)\n" +
            "Description: Returns the number of terminal columns the string s (or\n" +
            "its substring from start to end) occupies, summing char-width over its\n" +
            "code points. Surrogate pairs count as one code point; control\n" +
            "characters count as 0.\n" +
            "Example:\n" +
            "  (string-width \"abc\") => 3\n" +
            "  (string-width \"\\x4E2D;\\x6587;\") => 4";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        char[] s = Value.AsString(arguments[0]);
        int start = arguments.Length > 1 ? IntegerMath.ToInt(arguments[1]) : 0;
        int end = arguments.Length > 2 ? IntegerMath.ToInt(arguments[2]) : s.Length;
        if (start < 0 || end > s.Length || start > end)
            throw new SchemeError(pos, "string-width: invalid range");
        long total = 0;
        int i = start;
        while (i < end)
        {
            char c = s[i];
            int cp = c;
            if (char.IsHighSurrogate(c) && i + 1 < end && char.IsLowSurrogate(s[i + 1]))
            {
                cp = char.ConvertToUtf32(c, s[i + 1]);
                i += 2;
            }
            else
            {
                i++;
            }
            int w = CharWidth.Width(cp);
            if (w > 0) total += w;
        }
        return total;
    }
}
