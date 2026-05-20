package scheme.repl;

/**
 * Tiny scheme-aware scanner used by the line editor. It is intentionally
 * forgiving: it must work on partial input mid-edit. Strings, line
 * comments, block comments and #; datum-comments are all skipped so
 * that parentheses inside them don't fool the scanner.
 */
public final class SexpScanner {

    private SexpScanner() {}

    /** Returns the net paren depth at the end of the buffer (positive = unbalanced opens). */
    public static int depth(CharSequence s) {
        int depth = 0;
        int i = 0; int n = s.length();
        while (i < n) {
            i = skipNonCode(s, i);
            if (i >= n) break;
            char c = s.charAt(i);
            if (c == '(' || c == '[') depth++;
            else if (c == ')' || c == ']') depth--;
            i++;
        }
        return depth;
    }

    public static boolean balanced(CharSequence s) { return depth(s) == 0; }

    /**
     * Indent column for a new continuation line: the column of the second
     * element of the innermost unclosed form. If the innermost form has not
     * yet seen a second element, falls back to {@code openCol + 1}.
     *
     * Examples (prompt of width {@code promptCols}):
     *   "(+ 1"            -> column of '1'
     *   "(let ((x 1)"     -> column of '(' (the first binding)
     *   "(define"         -> openCol + 1 (no second element yet)
     */
    public static int continuationIndent(CharSequence s, int promptCols) {
        final int CAP = 256;
        int[] openCol = new int[CAP];
        int[] secondCol = new int[CAP];
        boolean[] seenFirst = new boolean[CAP];
        int sp = 0;
        int col = promptCols;
        int n = s.length();
        int i = 0;
        boolean inAtom = false;

        while (i < n) {
            char c = s.charAt(i);

            // Line comment
            if (c == ';') {
                while (i < n && s.charAt(i) != '\n') { col++; i++; }
                inAtom = false;
                continue;
            }
            // Block comment #| ... |#
            if (c == '#' && i + 1 < n && s.charAt(i + 1) == '|') {
                col += 2; i += 2;
                while (i + 1 < n && !(s.charAt(i) == '|' && s.charAt(i + 1) == '#')) {
                    if (s.charAt(i) == '\n') col = 0; else col++;
                    i++;
                }
                if (i + 1 < n) { col += 2; i += 2; }
                inAtom = false;
                continue;
            }
            // String literal — starts a token
            if (c == '"') {
                if (sp > 0) recordToken(sp - 1, col, seenFirst, secondCol);
                col++; i++;
                while (i < n) {
                    char d = s.charAt(i);
                    if (d == '\\' && i + 1 < n) { col += 2; i += 2; continue; }
                    if (d == '"') { col++; i++; break; }
                    if (d == '\n') col = 0; else col++;
                    i++;
                }
                inAtom = false;
                continue;
            }
            if (c == '\n') { col = 0; i++; inAtom = false; continue; }
            if (c == ' ' || c == '\t') { col++; i++; inAtom = false; continue; }
            if (c == '(' || c == '[') {
                if (sp > 0) recordToken(sp - 1, col, seenFirst, secondCol);
                if (sp < CAP) {
                    openCol[sp] = col;
                    secondCol[sp] = -1;
                    seenFirst[sp] = false;
                }
                sp++;
                col++; i++;
                inAtom = false;
                continue;
            }
            if (c == ')' || c == ']') {
                if (sp > 0) sp--;
                col++; i++;
                inAtom = false;
                continue;
            }
            // Atom char (incl. ', `, ,, # — quote characters start their own token)
            if (!inAtom) {
                inAtom = true;
                if (sp > 0) recordToken(sp - 1, col, seenFirst, secondCol);
            }
            col++; i++;
        }

        if (sp == 0) return 0;
        int t = sp - 1;
        return secondCol[t] >= 0 ? secondCol[t] : openCol[t] + 1;
    }

    private static void recordToken(int t, int col, boolean[] seenFirst, int[] secondCol) {
        if (!seenFirst[t]) seenFirst[t] = true;
        else if (secondCol[t] < 0) secondCol[t] = col;
    }

    /** Index of the paren that matches the one at index i, or -1. */
    public static int matchingParen(CharSequence s, int idx) {
        if (idx < 0 || idx >= s.length()) return -1;
        char here = s.charAt(idx);
        boolean open = (here == '(' || here == '[');
        boolean close = (here == ')' || here == ']');
        if (!open && !close) return -1;
        if (open) {
            int depth = 0;
            int n = s.length();
            int i = 0;
            // Re-scan from start to honor strings/comments correctly
            while (i < n) {
                i = skipNonCode(s, i);
                if (i >= n) break;
                char c = s.charAt(i);
                if (i == idx) { depth = 1; i++; continue; }
                if (i > idx) {
                    if (c == '(' || c == '[') depth++;
                    else if (c == ')' || c == ']') { depth--; if (depth == 0) return i; }
                }
                i++;
            }
            return -1;
        } else {
            // Scan from start, recording last opens by depth
            int n = s.length();
            int i = 0;
            int[] openStack = new int[128];
            int sp = 0;
            while (i < n) {
                i = skipNonCode(s, i);
                if (i >= n) break;
                char c = s.charAt(i);
                if (c == '(' || c == '[') {
                    if (sp < openStack.length) openStack[sp] = i;
                    sp++;
                } else if (c == ')' || c == ']') {
                    if (i == idx) return sp > 0 ? openStack[sp - 1] : -1;
                    if (sp > 0) sp--;
                }
                i++;
            }
            return -1;
        }
    }

    /** Range [start,end) of the sexp at or containing index i. Returns null if none. */
    public static int[] sexpRangeAt(CharSequence s, int idx) {
        if (idx < 0 || idx >= s.length()) return null;
        char c = s.charAt(idx);
        if (c == '(' || c == '[') {
            int m = matchingParen(s, idx);
            if (m < 0) return null;
            return new int[]{idx, m + 1};
        }
        if (c == ')' || c == ']') {
            int m = matchingParen(s, idx);
            if (m < 0) return null;
            return new int[]{m, idx + 1};
        }
        return null;
    }

    /**
     * Find the "atom" (run of symbol chars) immediately ending at {@code cursor}.
     * Returns null if none. The first element is the start index in s, the
     * second is the cursor (i.e. end exclusive).
     */
    public static int[] atomBefore(CharSequence s, int cursor) {
        int i = cursor;
        while (i > 0 && isSymbolChar(s.charAt(i - 1))) i--;
        if (i == cursor) return null;
        return new int[]{i, cursor};
    }

    /**
     * Find the atom under the cursor (the symbol whose characters include the
     * char at or immediately before the cursor). Used by the info line.
     */
    public static int[] atomAt(CharSequence s, int cursor) {
        int n = s.length();
        int i = cursor;
        if (i > 0 && isSymbolChar(s.charAt(i - 1))) {
            while (i > 0 && isSymbolChar(s.charAt(i - 1))) i--;
        } else if (i < n && isSymbolChar(s.charAt(i))) {
            // cursor sits on a symbol char (rare for end-of-line use)
        } else {
            return null;
        }
        int start = i;
        int j = (cursor > 0 && isSymbolChar(s.charAt(cursor - 1))) ? cursor : cursor;
        // Extend right to include the rest of the symbol
        while (j < n && isSymbolChar(s.charAt(j))) j++;
        if (j == start) return null;
        return new int[]{start, j};
    }

    public static boolean isSymbolChar(char c) {
        if (c <= ' ') return false;
        switch (c) {
            case '(': case ')': case '[': case ']':
            case '\'': case '`': case ',':
            case '"': case ';':
                return false;
            default:
                return true;
        }
    }

    // --- non-code skipping (strings, comments) ---

    /** If s[i] starts non-code, advance past it; else return i. */
    static int skipNonCode(CharSequence s, int i) {
        int n = s.length();
        while (i < n) {
            char c = s.charAt(i);
            if (c == ';') {                       // line comment
                while (i < n && s.charAt(i) != '\n') i++;
            } else if (c == '"') {                // string
                i++;
                while (i < n) {
                    char d = s.charAt(i);
                    if (d == '\\' && i + 1 < n) { i += 2; continue; }
                    if (d == '"') { i++; break; }
                    i++;
                }
            } else if (c == '#' && i + 1 < n && s.charAt(i + 1) == '|') {  // block comment
                i += 2;
                while (i + 1 < n && !(s.charAt(i) == '|' && s.charAt(i + 1) == '#')) i++;
                if (i + 1 < n) i += 2;
            } else {
                return i;
            }
        }
        return i;
    }

    // Variant used by continuationIndent — same logic; provided as a separate
    // method to make it clear the column tracking caller advances on its own.
    static int skipNonCodeWithColumn(CharSequence s, int i, int col) {
        return skipNonCode(s, i);
    }
}
