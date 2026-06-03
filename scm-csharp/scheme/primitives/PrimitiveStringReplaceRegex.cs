using System.Collections.Concurrent;
using System.Text;
using System.Text.RegularExpressions;

namespace scheme;

public class PrimitiveStringReplaceRegex : Primitive
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

    private static string Expand(string template, Match m)
    {
        var sb = new StringBuilder();
        var i = 0;
        while (i < template.Length)
        {
            var c = template[i];
            if (c == '~' && i + 1 < template.Length)
            {
                var n = template[i + 1];
                if (n == '~')
                {
                    sb.Append('~');
                    i += 2;
                }
                else if (char.IsDigit(n))
                {
                    var j = i + 1;
                    while (j < template.Length && char.IsDigit(template[j])) j++;
                    var g = int.Parse(template.Substring(i + 1, j - (i + 1)));
                    if (g < m.Groups.Count) sb.Append(m.Groups[g].Value);
                    i = j;
                }
                else
                {
                    sb.Append(c);
                    i++;
                }
            }
            else
            {
                sb.Append(c);
                i++;
            }
        }
        return sb.ToString();
    }

    public override string Name()
    {
        return "string-replace-all-regex";
    }

    public override string Info()
    {
        return
            "Syntax: (string-replace-all-regex s pattern replacement)\n" +
            "Library: (scm string)\n" +
            "Description: Returns a new string with all matches of the regular expression pattern in s replaced by replacement. The replacement may refer to captured groups with ~0 (the whole match), ~1, ~2, ... (parenthesized groups). Use ~~ for a literal tilde. References to groups that did not participate in the match expand to the empty string.\n" +
            "Example:\n" +
            "  (string-replace-all-regex \"hello world\" \"o\" \"0\") => \"hell0 w0rld\"\n" +
            "  (string-replace-all-regex \"2024-01-31\" \"([0-9]+)-([0-9]+)-([0-9]+)\" \"~3.~2.~1\") => \"31.01.2024\"\n" +
            "  (string-replace-all-regex \"abc123def456\" \"[0-9]+\" \"#\") => \"abc#def#\"";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        var s = new String(Value.AsString(arguments[0]));
        var regexp = Get(new String(Value.AsString(arguments[1])));
        var replace = new String(Value.AsString(arguments[2]));
        return regexp.Replace(s, m => Expand(replace, m)).ToCharArray();
    }
}
