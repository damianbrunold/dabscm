namespace schemerepl;

/// <summary>
/// Tiny scheme-aware scanner mirroring scheme.repl.SexpScanner.
/// </summary>
public static class SexpScanner
{
    public static int Depth(string s)
    {
        int depth = 0; int i = 0; int n = s.Length;
        while (i < n)
        {
            i = SkipNonCode(s, i);
            if (i >= n) break;
            char c = s[i];
            if (c == '(' || c == '[') depth++;
            else if (c == ')' || c == ']') depth--;
            i++;
        }
        return depth;
    }

    public static bool Balanced(string s) => Depth(s) == 0;

    /// <summary>
    /// Indent column for a new continuation line: the column of the second
    /// element of the innermost unclosed form. If the innermost form has not
    /// yet seen a second element, falls back to openCol + 1.
    /// </summary>
    public static int ContinuationIndent(string s, int promptCols)
    {
        const int Cap = 256;
        var openCol = new int[Cap];
        var secondCol = new int[Cap];
        var seenFirst = new bool[Cap];
        int sp = 0;
        int col = promptCols;
        int n = s.Length;
        int i = 0;
        bool inAtom = false;

        while (i < n)
        {
            char c = s[i];
            if (c == ';')
            {
                while (i < n && s[i] != '\n') { col++; i++; }
                inAtom = false;
                continue;
            }
            if (c == '#' && i + 1 < n && s[i + 1] == '|')
            {
                col += 2; i += 2;
                while (i + 1 < n && !(s[i] == '|' && s[i + 1] == '#'))
                {
                    if (s[i] == '\n') col = 0; else col++;
                    i++;
                }
                if (i + 1 < n) { col += 2; i += 2; }
                inAtom = false;
                continue;
            }
            if (c == '"')
            {
                if (sp > 0) RecordToken(sp - 1, col, seenFirst, secondCol);
                col++; i++;
                while (i < n)
                {
                    char d = s[i];
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
            if (c == '(' || c == '[')
            {
                if (sp > 0) RecordToken(sp - 1, col, seenFirst, secondCol);
                if (sp < Cap)
                {
                    openCol[sp] = col;
                    secondCol[sp] = -1;
                    seenFirst[sp] = false;
                }
                sp++;
                col++; i++;
                inAtom = false;
                continue;
            }
            if (c == ')' || c == ']')
            {
                if (sp > 0) sp--;
                col++; i++;
                inAtom = false;
                continue;
            }
            if (!inAtom)
            {
                inAtom = true;
                if (sp > 0) RecordToken(sp - 1, col, seenFirst, secondCol);
            }
            col++; i++;
        }

        if (sp == 0) return 0;
        int t = sp - 1;
        return secondCol[t] >= 0 ? secondCol[t] : openCol[t] + 1;
    }

    private static void RecordToken(int t, int col, bool[] seenFirst, int[] secondCol)
    {
        if (!seenFirst[t]) seenFirst[t] = true;
        else if (secondCol[t] < 0) secondCol[t] = col;
    }

    public static int MatchingParen(string s, int idx)
    {
        if (idx < 0 || idx >= s.Length) return -1;
        char here = s[idx];
        bool open = (here == '(' || here == '[');
        bool close = (here == ')' || here == ']');
        if (!open && !close) return -1;
        int n = s.Length;
        if (open)
        {
            int depth = 0; int i = 0;
            while (i < n)
            {
                i = SkipNonCode(s, i);
                if (i >= n) break;
                char c = s[i];
                if (i == idx) { depth = 1; i++; continue; }
                if (i > idx)
                {
                    if (c == '(' || c == '[') depth++;
                    else if (c == ')' || c == ']') { depth--; if (depth == 0) return i; }
                }
                i++;
            }
            return -1;
        }
        else
        {
            int i = 0; var openStack = new int[128]; int sp = 0;
            while (i < n)
            {
                i = SkipNonCode(s, i);
                if (i >= n) break;
                char c = s[i];
                if (c == '(' || c == '[') { if (sp < openStack.Length) openStack[sp] = i; sp++; }
                else if (c == ')' || c == ']')
                {
                    if (i == idx) return sp > 0 ? openStack[sp - 1] : -1;
                    if (sp > 0) sp--;
                }
                i++;
            }
            return -1;
        }
    }

    public static (int, int)? SexpRangeAt(string s, int idx)
    {
        if (idx < 0 || idx >= s.Length) return null;
        char c = s[idx];
        if (c == '(' || c == '[')
        {
            int m = MatchingParen(s, idx);
            if (m < 0) return null;
            return (idx, m + 1);
        }
        if (c == ')' || c == ']')
        {
            int m = MatchingParen(s, idx);
            if (m < 0) return null;
            return (m, idx + 1);
        }
        return null;
    }

    public static (int, int)? AtomBefore(string s, int cursor)
    {
        int i = cursor;
        while (i > 0 && IsSymbolChar(s[i - 1])) i--;
        if (i == cursor) return null;
        return (i, cursor);
    }

    public static (int, int)? AtomAt(string s, int cursor)
    {
        int n = s.Length;
        int i = cursor;
        if (i > 0 && IsSymbolChar(s[i - 1]))
        {
            while (i > 0 && IsSymbolChar(s[i - 1])) i--;
        }
        else if (i < n && IsSymbolChar(s[i]))
        {
            // ok, cursor on symbol char
        }
        else
        {
            return null;
        }
        int start = i;
        int j = cursor;
        while (j < n && IsSymbolChar(s[j])) j++;
        if (j == start) return null;
        return (start, j);
    }

    public static bool IsSymbolChar(char c)
    {
        if (c <= ' ') return false;
        switch (c)
        {
            case '(': case ')': case '[': case ']':
            case '\'': case '`': case ',':
            case '"': case ';':
                return false;
            default:
                return true;
        }
    }

    private static int SkipNonCode(string s, int i)
    {
        int n = s.Length;
        while (i < n)
        {
            char c = s[i];
            if (c == ';')
            {
                while (i < n && s[i] != '\n') i++;
            }
            else if (c == '"')
            {
                i++;
                while (i < n)
                {
                    char d = s[i];
                    if (d == '\\' && i + 1 < n) { i += 2; continue; }
                    if (d == '"') { i++; break; }
                    i++;
                }
            }
            else if (c == '#' && i + 1 < n && s[i + 1] == '|')
            {
                i += 2;
                while (i + 1 < n && !(s[i] == '|' && s[i + 1] == '#')) i++;
                if (i + 1 < n) i += 2;
            }
            else
            {
                return i;
            }
        }
        return i;
    }
}
