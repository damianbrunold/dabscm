using System.Collections.Concurrent;
using System.Text.RegularExpressions;

namespace scheme;

public class PrimitiveStringSplit : Primitive
{
    internal static readonly ConcurrentDictionary<string, Regex> SplitCache = new();
    internal static Regex GetSplitRegex(string pattern)
    {
        if (SplitCache.TryGetValue(pattern, out var r)) return r;
        var fresh = new Regex(pattern, RegexOptions.IgnoreCase, TimeSpan.FromMilliseconds(2000));
        if (SplitCache.Count > 256) SplitCache.Clear();
        SplitCache.TryAdd(pattern, fresh);
        return fresh;
    }

    public override string Name()
    {
        return "string-split";
    }

    public override string Info()
    {
        return
            "Syntax: (string-split s pattern?)\n" +
            "Library: (scm string)\n" +
            "Description: Splits the string s at occurrences of the regular expression pattern and returns a list of the resulting substrings. Defaults to splitting on whitespace.\n" +
            "Example:\n" +
            "  (string-split \"a b c\") => (\"a\" \"b\" \"c\")\n" +
            "  (string-split \"a,b,c\" \",\") => (\"a\" \"b\" \"c\")";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        string s = new String(Value.AsString(arguments[0]));
        string regexp = "[ \\t\\r\\n]+";
        if (arguments.Length > 1) regexp = new String(Value.AsString(arguments[1]));
        string[] parts = GetSplitRegex(regexp).Split(s);
        object result = Value.NIL;
        for (int i = parts.Length - 1; i >= 0; i--)
        {
            result = new Pair(parts[i].ToCharArray(), result);
        }
        return result;
    }
}
