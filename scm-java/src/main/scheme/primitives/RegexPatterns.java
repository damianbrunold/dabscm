package scheme.primitives;

import java.util.regex.Pattern;
import java.util.regex.PatternSyntaxException;
import scheme.SchemeError;

/** Pattern compilation with the error message every regex primitive gives. */
final class RegexPatterns {
    private RegexPatterns() {}

    // A syntax error as "<who>: invalid pattern: <description>" (the native
    // implementation gives the same text)
    static Pattern compile(String who, String pattern) {
        try {
            return Pattern.compile(pattern);
        } catch (PatternSyntaxException e) {
            throw new SchemeError(who + ": invalid pattern: ~a", e.getDescription());
        }
    }
}
