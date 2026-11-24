using System.Text.RegularExpressions;

namespace scheme;

/// Pattern compilation with the error message every regex primitive gives:
/// "<who>: invalid pattern: <description>", in java.util.regex's words as the
/// JVM and native implementations give them
public static class RegexPatterns
{
    public static Regex Compile(string who, string pattern, RegexOptions options = RegexOptions.None)
    {
        try
        {
            return new Regex(pattern, options);
        }
        catch (RegexParseException e)
        {
            throw new SchemeError(who + ": invalid pattern: ~a", Describe(e, pattern));
        }
    }

    static string Describe(RegexParseException e, string pattern)
    {
        switch (e.Error)
        {
            case RegexParseError.InsufficientClosingParentheses: return "Unclosed group";
            case RegexParseError.InsufficientOpeningParentheses: return "Unmatched closing ')'";
            case RegexParseError.QuantifierAfterNothing:
                {
                    int i = Math.Clamp(e.Offset - 1, 0, Math.Max(0, pattern.Length - 1));
                    char c = pattern.Length > 0 ? pattern[i] : '?';
                    return c == '{' ? "Illegal repetition" : "Dangling meta character '" + c + "'";
                }
            case RegexParseError.UnterminatedBracket: return "Unclosed character class";
            case RegexParseError.ReversedCharacterRange: return "Illegal character range";
            case RegexParseError.ReversedQuantifierRange: return "Illegal repetition range";
            case RegexParseError.UnrecognizedEscape: return "Illegal/unsupported escape sequence";
            case RegexParseError.UnescapedEndingBackslash: return "Unexpected internal error";
            default: return e.Message;
        }
    }
}
