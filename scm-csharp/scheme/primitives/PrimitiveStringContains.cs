namespace scheme;

public class PrimitiveStringContains : Primitive
{
    public override string Name()
    {
        return "string-contains";
    }

    public override string Info()
    {
        return
            "Syntax: (string-contains s1 s2 [start1 [end1 [start2 [end2]]]])\n" +
            "Library: (srfi 13)\n" +
            "Description: Returns the index of the first occurrence of s2[start2..end2) in s1[start1..end1), or #f if not found.\n" +
            "Example:\n" +
            "  (string-contains \"hello world\" \"world\") => 6\n" +
            "  (string-contains \"hello\" \"xyz\") => #f\n" +
            "  (string-contains \"abcabc\" \"b\" 2) => 4";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 6);
        var s = new String(Value.AsString(arguments[0]));
        var what = new String(Value.AsString(arguments[1]));
        var start1 = 0;
        var end1 = s.Length;
        var start2 = 0;
        var end2 = what.Length;
        if (arguments.Length >= 3)
        {
            start1 = IntegerMath.ToInt(arguments[2]);
            if (start1 < 0) start1 = s.Length + start1;
        }
        if (arguments.Length >= 4)
            end1 = IntegerMath.ToInt(arguments[3]);
        if (arguments.Length >= 5)
            start2 = IntegerMath.ToInt(arguments[4]);
        if (arguments.Length >= 6)
            end2 = IntegerMath.ToInt(arguments[5]);
        var region = s.Substring(start1, end1 - start1);
        var pattern = what.Substring(start2, end2 - start2);
        var idx = region.IndexOf(pattern);
        if (idx == -1) return Value.F;
        return (long) (idx + start1);
    }
}
