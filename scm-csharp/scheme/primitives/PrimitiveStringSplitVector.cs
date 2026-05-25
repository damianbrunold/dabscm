using System.Text.RegularExpressions;

namespace scheme;

public class PrimitiveStringSplitVector : Primitive
{
    public override string Name()
    {
        return "string-split-vector";
    }

    public override string Info()
    {
        return
            "Syntax: (string-split-vector s pattern?)\n" +
            "Library: (scm string)\n" +
            "Description: Splits the string s at occurrences of the regular expression pattern and returns a vector of the resulting substrings. Defaults to splitting on whitespace.\n" +
            "Example:\n" +
            "  (string-split-vector \"a b c\") => #(\"a\" \"b\" \"c\")\n" +
            "  (string-split-vector \"a,b,c\" \",\") => #(\"a\" \"b\" \"c\")";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        string s = new String(Value.AsString(arguments[0]));
        string regexp = "[ \\t\\r\\n]+";
        if (arguments.Length > 1) regexp = new String(Value.AsString(arguments[1]));
        string[] parts = PrimitiveStringSplit.GetSplitRegex(regexp).Split(s);
        var result = new object[parts.Length];
        for (int i = 0; i < parts.Length; i++) result[i] = parts[i].ToCharArray();
        return result;
    }
}
