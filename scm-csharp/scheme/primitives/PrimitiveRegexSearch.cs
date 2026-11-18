using System.Collections.Concurrent;
using System.Text.RegularExpressions;

namespace scheme;

public class PrimitiveRegexSearch : Primitive
{
    private static readonly ConcurrentDictionary<string, Regex> cache = new();
    private static Regex Get(string pattern)
    {
        if (cache.TryGetValue(pattern, out var r)) return r;
        var fresh = new Regex(pattern);
        if (cache.Count > 256) cache.Clear();
        cache.TryAdd(pattern, fresh);
        return fresh;
    }

    public override string Name()
    {
        return "regex-search";
    }

    public override string Info()
    {
        return
            "Syntax: (regex-search s pattern [start])\n" +
            "Library: (scm string)\n" +
            "Description: Searches s for the first match of the regular expression\n" +
            "pattern at or after index start (default 0). Returns a vector with one\n" +
            "entry per group, the whole match first: each entry is a pair\n" +
            "(start . end) of string indexes, or #f for a group that does not take\n" +
            "part in the match. Returns #f if there is no match. Lookbehind, \\b and\n" +
            "^ see the characters before start, so ^ only matches at index 0 unless\n" +
            "the pattern enables multi-line mode with (?m). The pattern syntax is\n" +
            "that of the host regex engine (java.util.regex or .NET Regex); the\n" +
            "common subset (classes, quantifiers, groups, (?i), (?m), lookaround)\n" +
            "behaves the same in both.\n" +
            "Example:\n" +
            "  (regex-search \"abc123\" \"([a-z]+)([0-9]+)\") => #((0 . 6) (0 . 3) (3 . 6))\n" +
            "  (regex-search \"ab ab\" \"ab\" 1) => #((3 . 5))\n" +
            "  (regex-search \"b\" \"(x)?b\") => #((0 . 1) #f)\n" +
            "  (regex-search \"hello\" \"xyz\") => #f";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        var s = new String(Value.AsString(arguments[0]));
        Regex regex;
        try
        {
            regex = Get(new String(Value.AsString(arguments[1])));
        }
        catch (ArgumentException e)
        {
            throw new SchemeError(pos, "regex-search: invalid pattern: ~a", e.Message);
        }
        int start = arguments.Length > 2 ? IntegerMath.ToInt(arguments[2]) : 0;
        if (start < 0 || start > s.Length)
            throw new SchemeError(pos, "regex-search: start ~a out of range", (long) start);
        var m = regex.Match(s, start);
        if (!m.Success) return Value.F;
        // .NET numbers named groups after the unnamed ones; keep the numeric order.
        var numbers = regex.GetGroupNumbers();
        int count = 0;
        foreach (var n in numbers) if (n + 1 > count) count = n + 1;
        var result = new object[count];
        for (int i = 0; i < count; i++)
        {
            var g = m.Groups[i];
            result[i] = g.Success ? new Pair((long) g.Index, (long) (g.Index + g.Length)) : Value.F;
        }
        return result;
    }
}
