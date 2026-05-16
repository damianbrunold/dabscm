namespace scheme;

public class PrimitiveStringReplace : Primitive
{
    public override string Name()
    {
        return "string-replace-all";
    }

    public override string Info()
    {
        return
            "Syntax: (string-replace-all s pattern replacement)\n" +
            "Library: (scm string)\n" +
            "Description: Returns a new string with all occurrences of pattern in s replaced by replacement.\n" +
            "Example:\n" +
            "  (string-replace-all \"hello world\" \"world\" \"there\") => \"hello there\"\n" +
            "  (string-replace-all \"aabbcc\" \"b\" \"x\") => \"aaxxcc\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        var s = new String(Value.AsString(arguments[0]));
        var what = new String(Value.AsString(arguments[1]));
        var replace = new String(Value.AsString(arguments[2]));
        return s.Replace(what, replace).ToCharArray();
    }
}
