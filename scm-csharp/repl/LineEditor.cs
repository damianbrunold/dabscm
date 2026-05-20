using System.Text;

namespace schemerepl;

public sealed class LineEditor
{
    private readonly Terminal term;
    private readonly KeyReader keys;
    private readonly History history;
    private readonly ICompletionProvider completions;

    private readonly StringBuilder buf = new();
    private int cursor;
    private string prompt = "> ";
    private string contIndent = "  ";
    private int lastFrameRows;
    private int lastFramePhysRow;
    private int historyPos;
    private string savedNewLine = "";
    private IList<string>? lastCompletions;
    private bool lastKeyWasTab;
    private string infoLineText = "";
    private string lastInfoName = "";

    public LineEditor(Terminal term, History history, ICompletionProvider completions)
    {
        this.term = term;
        this.keys = new KeyReader(term);
        this.history = history;
        this.completions = completions;
    }

    public string? ReadSexp(string prompt)
    {
        this.prompt = prompt;
        var pad = new StringBuilder();
        for (int i = 0; i < VisibleLength(prompt); i++) pad.Append(' ');
        contIndent = pad.ToString();
        buf.Clear();
        cursor = 0;
        historyPos = history.Count;
        savedNewLine = "";
        lastCompletions = null;
        lastKeyWasTab = false;
        infoLineText = "";
        lastInfoName = "";
        lastFrameRows = 0;
        lastFramePhysRow = 0;

        RefreshInfo();
        Redraw();

        while (true)
        {
            var k = keys.Next();
            bool? action = Handle(k);
            if (action == null)
            {
                MoveCursorToFrameBottom();
                term.Write("\n");
                var s = buf.ToString();
                if (s.Length > 0) history.Add(s);
                return s;
            }
            if (action == false) return null; // EOF
            if (k.Type != KeyType.Tab) lastKeyWasTab = false;
            RefreshInfo();
            Redraw();
        }
    }

    // null = submit, true = continue, false = EOF
    private bool? Handle(Key k)
    {
        switch (k.Type)
        {
            case KeyType.Enter:
                if (SexpScanner.Balanced(buf.ToString()) && buf.ToString().Trim().Length > 0) return null;
                if (buf.Length == 0) return null;
                int indent = SexpScanner.ContinuationIndent(buf.ToString(), VisibleLength(prompt));
                var ins = new StringBuilder("\n");
                int spaces = Math.Max(0, indent - VisibleLength(prompt));
                for (int i = 0; i < spaces; i++) ins.Append(' ');
                buf.Insert(cursor, ins.ToString());
                cursor += ins.Length;
                return true;
            case KeyType.EOF:
                if (buf.Length == 0)
                {
                    MoveCursorToFrameBottom();
                    term.Write("\n");
                    return false;
                }
                return true;
            case KeyType.Interrupt:
                if (buf.Length == 0)
                {
                    MoveCursorToFrameBottom();
                    term.Write("^C\n");
                    return false;
                }
                MoveCursorToFrameBottom();
                term.Write("^C\n");
                buf.Clear(); cursor = 0;
                historyPos = history.Count;
                lastFrameRows = 0; lastFramePhysRow = 0;
                return true;
            case KeyType.Tab:
                TabComplete();
                return true;
            case KeyType.Backspace:
                if (cursor > 0) { buf.Remove(cursor - 1, 1); cursor--; }
                return true;
            case KeyType.Delete:
                if (k.Ctrl)
                {
                    if (cursor < buf.Length)
                    {
                        char c = buf[cursor];
                        if (c == '(' || c == ')' || c == '[' || c == ']')
                        {
                            var r = SexpScanner.SexpRangeAt(buf.ToString(), cursor);
                            if (r.HasValue)
                            {
                                buf.Remove(r.Value.Item1, r.Value.Item2 - r.Value.Item1);
                                cursor = r.Value.Item1;
                                return true;
                            }
                        }
                    }
                    DeleteWordRight();
                }
                else if (cursor < buf.Length) buf.Remove(cursor, 1);
                return true;
            case KeyType.Left:
                if (k.Ctrl)
                {
                    if (cursor < buf.Length)
                    {
                        char c = buf[cursor];
                        if (c == ')' || c == ']')
                        {
                            int m = SexpScanner.MatchingParen(buf.ToString(), cursor);
                            if (m >= 0) { cursor = m; return true; }
                        }
                    }
                    if (cursor > 0)
                    {
                        char c2 = buf[cursor - 1];
                        if (c2 == ')' || c2 == ']')
                        {
                            int m = SexpScanner.MatchingParen(buf.ToString(), cursor - 1);
                            if (m >= 0) { cursor = m; return true; }
                        }
                    }
                    MoveWordLeft();
                }
                else if (cursor > 0) cursor--;
                return true;
            case KeyType.Right:
                if (k.Ctrl)
                {
                    if (cursor < buf.Length)
                    {
                        char c = buf[cursor];
                        if (c == '(' || c == '[')
                        {
                            int m = SexpScanner.MatchingParen(buf.ToString(), cursor);
                            if (m >= 0) { cursor = m + 1; return true; }
                        }
                    }
                    MoveWordRight();
                }
                else if (cursor < buf.Length) cursor++;
                return true;
            case KeyType.Up:
                if (LogicalRowOfCursor() == 0) HistoryPrev();
                else MoveCursorVertical(-1);
                return true;
            case KeyType.Down:
                if (LogicalRowOfCursor() == LogicalLineCount() - 1) HistoryNext();
                else MoveCursorVertical(+1);
                return true;
            case KeyType.Home: cursor = StartOfLogicalLine(cursor); return true;
            case KeyType.End:  cursor = EndOfLogicalLine(cursor);   return true;
            case KeyType.Esc:
                buf.Clear(); cursor = 0; historyPos = history.Count;
                return true;
            case KeyType.Char:
                if (k.Ctrl) return HandleCtrl(k);
                if (k.Alt) return true;
                if (k.Ch >= 0x20) { buf.Insert(cursor, (char)k.Ch); cursor++; }
                return true;
            default:
                return true;
        }
    }

    private bool? HandleCtrl(Key k)
    {
        switch (k.Ch)
        {
            case 'A': cursor = StartOfLogicalLine(cursor); return true;
            case 'E': cursor = EndOfLogicalLine(cursor); return true;
            case 'B': if (cursor > 0) cursor--; return true;
            case 'F': if (cursor < buf.Length) cursor++; return true;
            case 'K': buf.Remove(cursor, EndOfLogicalLine(cursor) - cursor); return true;
            case 'U':
                int s = StartOfLogicalLine(cursor);
                buf.Remove(s, cursor - s); cursor = s; return true;
            case 'W':
                int start = cursor;
                MoveWordLeft();
                buf.Remove(cursor, start - cursor);
                return true;
            case 'L':
                term.Write("\x1b[2J\x1b[H");
                lastFrameRows = 0; lastFramePhysRow = 0;
                return true;
            case 'R':
                ReverseSearch();
                return true;
            case 'D':
                if (cursor < buf.Length) { buf.Remove(cursor, 1); return true; }
                if (buf.Length == 0)
                {
                    MoveCursorToFrameBottom();
                    term.Write("\n");
                    return false;
                }
                return true;
            default:
                return true;
        }
    }

    private void HistoryPrev()
    {
        if (history.Count == 0) return;
        if (historyPos == history.Count) savedNewLine = buf.ToString();
        if (historyPos > 0)
        {
            historyPos--;
            buf.Clear();
            buf.Append(history.Get(historyPos));
            cursor = buf.Length;
        }
    }

    private void HistoryNext()
    {
        if (historyPos >= history.Count) return;
        historyPos++;
        buf.Clear();
        if (historyPos == history.Count) buf.Append(savedNewLine);
        else buf.Append(history.Get(historyPos));
        cursor = buf.Length;
    }

    private void MoveWordLeft()
    {
        while (cursor > 0 && !SexpScanner.IsSymbolChar(buf[cursor - 1])) cursor--;
        while (cursor > 0 &&  SexpScanner.IsSymbolChar(buf[cursor - 1])) cursor--;
    }
    private void MoveWordRight()
    {
        int n = buf.Length;
        while (cursor < n && !SexpScanner.IsSymbolChar(buf[cursor])) cursor++;
        while (cursor < n &&  SexpScanner.IsSymbolChar(buf[cursor])) cursor++;
    }
    private void DeleteWordRight()
    {
        int start = cursor;
        MoveWordRight();
        buf.Remove(start, cursor - start);
        cursor = start;
    }

    private int StartOfLogicalLine(int idx)
    {
        while (idx > 0 && buf[idx - 1] != '\n') idx--;
        return idx;
    }
    private int EndOfLogicalLine(int idx)
    {
        int n = buf.Length;
        while (idx < n && buf[idx] != '\n') idx++;
        return idx;
    }
    private int LogicalRowOfCursor()
    {
        int r = 0;
        for (int i = 0; i < cursor; i++) if (buf[i] == '\n') r++;
        return r;
    }
    private int LogicalLineCount()
    {
        int n = 1;
        for (int i = 0; i < buf.Length; i++) if (buf[i] == '\n') n++;
        return n;
    }
    private int ColumnOfCursor()
    {
        int c = (LogicalRowOfCursor() == 0) ? VisibleLength(prompt) : VisibleLength(contIndent);
        int start = StartOfLogicalLine(cursor);
        return c + (cursor - start);
    }
    private void MoveCursorVertical(int delta)
    {
        int row = LogicalRowOfCursor();
        int target = row + delta;
        if (target < 0 || target >= LogicalLineCount()) return;
        int col = ColumnOfCursor();
        int idx = 0; int r = 0;
        while (idx < buf.Length && r < target)
        {
            if (buf[idx] == '\n') r++;
            idx++;
        }
        int lineStart = idx;
        int lineEnd = EndOfLogicalLine(idx);
        int rowIndent = (target == 0) ? VisibleLength(prompt) : VisibleLength(contIndent);
        int desiredOffset = Math.Max(0, col - rowIndent);
        int actualOffset = Math.Min(desiredOffset, lineEnd - lineStart);
        cursor = lineStart + actualOffset;
    }

    // ---- completion ----

    private void TabComplete()
    {
        var atom = SexpScanner.AtomBefore(buf.ToString(), cursor);
        if (!atom.HasValue) return;
        var (s0, s1) = atom.Value;
        string prefix = buf.ToString().Substring(s0, s1 - s0);
        var cs = completions.Completions(prefix);
        if (cs == null || cs.Count == 0)
        {
            infoLineText = "(no completions)";
            lastInfoName = "";
            return;
        }
        if (cs.Count == 1)
        {
            ReplaceRange(s0, s1, cs[0]);
            lastCompletions = null;
            return;
        }
        string common = CommonPrefix(cs);
        if (common.Length > prefix.Length)
        {
            ReplaceRange(s0, s1, common);
            lastCompletions = cs;
            return;
        }
        if (lastKeyWasTab && lastCompletions != null)
        {
            ShowCompletionList(lastCompletions);
            lastCompletions = null;
        }
        else
        {
            lastCompletions = cs;
            lastKeyWasTab = true;
        }
    }

    private void ReplaceRange(int start, int end, string repl)
    {
        buf.Remove(start, end - start);
        buf.Insert(start, repl);
        cursor = start + repl.Length;
    }

    private void ShowCompletionList(IList<string> cs)
    {
        MoveCursorToFrameBottom();
        term.Write("\n");
        int width = term.Width();
        int maxLen = 0;
        foreach (var s in cs) if (s.Length > maxLen) maxLen = s.Length;
        int colW = maxLen + 2;
        int cols = Math.Max(1, width / colW);
        var line = new StringBuilder();
        int i = 0;
        foreach (var s in cs)
        {
            line.Append(s);
            for (int k = s.Length; k < colW; k++) line.Append(' ');
            if ((++i) % cols == 0) { line.Append('\n'); term.Write(line.ToString()); line.Clear(); }
        }
        if (line.Length > 0) { line.Append('\n'); term.Write(line.ToString()); }
        lastFrameRows = 0; lastFramePhysRow = 0;
    }

    private static string CommonPrefix(IList<string> ss)
    {
        string a = ss[0];
        int n = a.Length;
        for (int i = 1; i < ss.Count; i++)
        {
            string b = ss[i];
            int m = Math.Min(n, b.Length);
            int j = 0;
            while (j < m && a[j] == b[j]) j++;
            n = j;
        }
        return a.Substring(0, n);
    }

    // ---- reverse search ----

    private void ReverseSearch()
    {
        var q = new StringBuilder();
        int hit = -1;
        while (true)
        {
            string header = "(reverse-i-search)`" + q + "': ";
            string shown = hit >= 0 ? history.Get(hit) : "";
            string oldPrompt = prompt;
            string oldContIndent = contIndent;
            var oldBuf = buf.ToString();
            int oldCursor = cursor;
            prompt = header;
            var pad = new StringBuilder();
            for (int i = 0; i < VisibleLength(header); i++) pad.Append(' ');
            contIndent = pad.ToString();
            buf.Clear(); buf.Append(shown.Replace('\n', ' '));
            cursor = buf.Length;
            RedrawImpl(false);
            prompt = oldPrompt; contIndent = oldContIndent;
            var k = keys.Next();
            if (k.Type == KeyType.Enter)
            {
                if (hit >= 0) { buf.Clear(); buf.Append(history.Get(hit)); cursor = buf.Length; }
                else { buf.Clear(); buf.Append(oldBuf); cursor = oldCursor; }
                return;
            }
            if (k.Type == KeyType.Esc || k.Type == KeyType.Interrupt)
            {
                buf.Clear(); buf.Append(oldBuf); cursor = oldCursor;
                return;
            }
            if (k.Type == KeyType.Backspace)
            {
                if (q.Length > 0) q.Remove(q.Length - 1, 1);
                hit = history.SearchBackward(q.ToString(), history.Count);
                buf.Clear(); buf.Append(oldBuf); cursor = oldCursor;
                continue;
            }
            if (k.Type == KeyType.Char && k.Ctrl && k.Ch == 'R')
            {
                hit = history.SearchBackward(q.ToString(), hit < 0 ? history.Count : hit);
                buf.Clear(); buf.Append(oldBuf); cursor = oldCursor;
                continue;
            }
            if (k.Type == KeyType.Char && !k.Ctrl && !k.Alt && k.Ch >= 0x20)
            {
                q.Append((char)k.Ch);
                hit = history.SearchBackward(q.ToString(), history.Count);
                buf.Clear(); buf.Append(oldBuf); cursor = oldCursor;
                continue;
            }
            buf.Clear(); buf.Append(oldBuf); cursor = oldCursor;
            return;
        }
    }

    // ---- info line ----

    private void RefreshInfo()
    {
        var atom = SexpScanner.AtomAt(buf.ToString(), cursor);
        string name = atom.HasValue ? buf.ToString().Substring(atom.Value.Item1, atom.Value.Item2 - atom.Value.Item1) : "";
        if (name == lastInfoName) return;
        lastInfoName = name;
        if (name.Length == 0) { infoLineText = ""; return; }
        try { infoLineText = completions.InfoLine(name) ?? ""; }
        catch { infoLineText = ""; }
    }

    // ---- redraw ----

    private void Redraw() => RedrawImpl(true);

    private void RedrawImpl(bool withInfo)
    {
        if (lastFramePhysRow > 0) term.Write($"\x1b[{lastFramePhysRow}A");
        term.Write("\r\x1b[J");

        int width = Math.Max(20, term.Width());

        // Matching-paren highlight indices.
        int hi1 = -1, hi2 = -1;
        if (cursor < buf.Length)
        {
            char c0 = buf[cursor];
            if (c0 == '(' || c0 == ')' || c0 == '[' || c0 == ']')
            {
                int m = SexpScanner.MatchingParen(buf.ToString(), cursor);
                if (m >= 0) { hi1 = cursor; hi2 = m; }
            }
        }
        if (hi1 < 0 && cursor > 0)
        {
            char c0 = buf[cursor - 1];
            if (c0 == ')' || c0 == ']')
            {
                int m = SexpScanner.MatchingParen(buf.ToString(), cursor - 1);
                if (m >= 0) { hi1 = cursor - 1; hi2 = m; }
            }
        }

        var sb = new StringBuilder();
        int physRow = 0;
        int physCol = 0;
        int cursorPhysRow = 0;
        int cursorPhysCol = 0;
        sb.Append(prompt);
        physCol = VisibleLength(prompt);

        for (int i = 0; i <= buf.Length; i++)
        {
            if (i == cursor)
            {
                cursorPhysRow = physRow;
                cursorPhysCol = physCol;
            }
            if (i == buf.Length) break;
            char c = buf[i];
            if (c == '\n')
            {
                sb.Append('\n').Append(contIndent);
                physRow++;
                physCol = VisibleLength(contIndent);
            }
            else
            {
                if (i == hi1 || i == hi2)
                    sb.Append("\x1b[7m").Append(c).Append("\x1b[0m");
                else
                    sb.Append(c);
                physCol++;
                if (physCol >= width) { physRow++; physCol = 0; }
            }
        }

        if (withInfo && infoLineText.Length > 0)
        {
            string info = infoLineText;
            if (VisibleLength(info) > width - 1) info = info.Substring(0, Math.Max(0, width - 4)) + "...";
            sb.Append('\n').Append("\x1b[2m").Append(info).Append("\x1b[0m");
            physRow++;
        }

        term.Write(sb.ToString());

        int endRow = physRow;
        int up = endRow - cursorPhysRow;
        if (up > 0) term.Write($"\x1b[{up}A");
        term.Write("\r");
        if (cursorPhysCol > 0) term.Write($"\x1b[{cursorPhysCol}C");

        lastFrameRows = physRow + 1;
        lastFramePhysRow = cursorPhysRow;
    }

    private void MoveCursorToFrameBottom()
    {
        int down = (lastFrameRows - 1) - lastFramePhysRow;
        if (down > 0) term.Write($"\x1b[{down}B");
        term.Write("\r");
        lastFrameRows = 0;
        lastFramePhysRow = 0;
    }

    private static int VisibleLength(string s)
    {
        int n = 0;
        bool inEsc = false;
        foreach (char c in s)
        {
            if (inEsc) { if (c >= 0x40 && c <= 0x7e) inEsc = false; continue; }
            if (c == 0x1b) { inEsc = true; continue; }
            if (c >= 0x20) n++;
        }
        return n;
    }
}
