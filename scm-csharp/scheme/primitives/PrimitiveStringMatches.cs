using System.Collections.Concurrent;
using System.Text.RegularExpressions;

namespace scheme;

public class PrimitiveStringMatches : Primitive
{
    private static readonly ConcurrentDictionary<string, Regex> cache = new();
    private static Regex Get(string pattern)
    {
        if (cache.TryGetValue(pattern, out var r)) return r;
        var fresh = RegexPatterns.Compile("string-matches", pattern);
        if (cache.Count > 256) cache.Clear();
        cache.TryAdd(pattern, fresh);
        return fresh;
    }

    public override string Name()
    {
        return "string-matches";
    }

    public override string Info()
    {
        return
            "Syntax: (string-matches s pattern)\n" +
            "Library: (scm string)\n" +
            "Description: Matches the string s against the regular expression pattern. Returns a list of match strings (the full match followed by any groups) if successful, or #f if there is no match. A group that does not take part in the match is #f.\n" +
            "Example:\n" +
            "  (string-matches \"hello\" \"hel+o\") => (\"hello\")\n" +
            "  (string-matches \"abc123\" \"([a-z]+)([0-9]+)\") => (\"abc123\" \"abc\" \"123\")\n" +
            "  (string-matches \"hello\" \"xyz\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var s = new String(Value.AsString(arguments[0]));
        var regexp = Get(new String(Value.AsString(arguments[1])));
        var match = regexp.Match(s);
        if (match.Success)
        {
            var groups = new object[match.Groups.Count];
            for (var i = 0; i < match.Groups.Count; i++)
            {
                var g = match.Groups[i];
                groups[i] = g.Success ? g.Value.ToCharArray() : Value.F;
            }
            return Pair.List(groups);
        }
        return Value.F;
    }
}
