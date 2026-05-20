package scheme.repl;

import java.io.IOException;
import java.util.List;

/**
 * Multi-line, sexp-aware line editor.
 *
 * The buffer is a single {@link StringBuilder} that may contain newlines.
 * Each redraw:
 *
 *   1. Moves the cursor back to the top of the previous frame.
 *   2. Clears to end of screen.
 *   3. Renders the prompt, the buffer (continuation lines indented under
 *      the prompt by promptLen spaces), and an info line below.
 *   4. Positions the cursor at the logical (row,col) of the buffer
 *      cursor.
 *
 * Wrapping: physical row tracking accounts for terminal width so the
 * "move to top" step is accurate even when content wraps.
 */
public final class LineEditor {

    private final Terminal term;
    private final KeyReader keys;
    private final History history;
    private final CompletionProvider completions;

    private StringBuilder buf = new StringBuilder();
    private int cursor = 0;
    private String prompt = "> ";
    private String contIndent = "  ";   // matches prompt width
    private int lastFrameRows = 0;      // physical rows the last frame drew
    private int lastFramePhysRow = 0;   // physical row of the cursor within last frame
    private int historyPos;             // index into history (== history.size() means "new entry")
    private String savedNewLine = "";   // buffer we set aside when moving into history
    private List<String> lastCompletions;
    private boolean lastKeyWasTab;
    private String infoLineText = "";
    private String lastInfoName = "";

    public LineEditor(Terminal term, History history, CompletionProvider completions) {
        this.term = term;
        this.keys = new KeyReader(term);
        this.history = history;
        this.completions = completions;
    }

    /** Block until the user submits a complete s-expression. */
    public String readSexp(String prompt) throws IOException {
        this.prompt = prompt;
        StringBuilder pad = new StringBuilder();
        for (int i = 0; i < visibleLength(prompt); i++) pad.append(' ');
        this.contIndent = pad.toString();
        buf.setLength(0);
        cursor = 0;
        historyPos = history.size();
        savedNewLine = "";
        lastCompletions = null;
        lastKeyWasTab = false;
        infoLineText = "";
        lastInfoName = "";
        lastFrameRows = 0;
        lastFramePhysRow = 0;

        // Initial draw
        refreshInfo();
        redraw();

        while (true) {
            Key k = keys.next();
            boolean handled = handle(k);
            if (handled == false) {
                // submit
                String out = buf.toString();
                // Move cursor below frame so the result prints on its own line
                moveCursorToFrameBottom();
                term.write("\n");
                if (!out.isEmpty()) history.add(out);
                return out;
            }
            if (k.type != Key.Type.TAB) lastKeyWasTab = false;
            refreshInfo();
            redraw();
        }
    }

    // Returns true to keep editing, false to submit.
    private boolean handle(Key k) throws IOException {
        switch (k.type) {
            case ENTER:
                if (SexpScanner.balanced(buf) && buf.toString().trim().length() > 0) return false;
                if (buf.length() == 0) return false; // empty submit -> just reprompt
                int indent = SexpScanner.continuationIndent(buf, visibleLength(prompt));
                StringBuilder ins = new StringBuilder("\n");
                int spaces = Math.max(0, indent - visibleLength(prompt));
                for (int i = 0; i < spaces; i++) ins.append(' ');
                buf.insert(cursor, ins.toString());
                cursor += ins.length();
                return true;
            case EOF:
                if (buf.length() == 0) {
                    // Signal EOF up the stack by returning an empty submit; REPL distinguishes via Ctrl+D semantics
                    moveCursorToFrameBottom();
                    term.write("\n");
                    throw new IOException("EOF");
                }
                return true;
            case INTERRUPT:
                // Ctrl+C: discard line. If already empty, also signal EOF.
                if (buf.length() == 0) {
                    moveCursorToFrameBottom();
                    term.write("^C\n");
                    throw new IOException("EOF");
                }
                moveCursorToFrameBottom();
                term.write("^C\n");
                buf.setLength(0); cursor = 0;
                historyPos = history.size();
                lastFrameRows = 0; lastFramePhysRow = 0;
                return true;
            case TAB: {
                tabComplete();
                return true;
            }
            case BACKSPACE:
                if (cursor > 0) { buf.deleteCharAt(cursor - 1); cursor--; }
                return true;
            case DELETE:
                if (k.ctrl) {
                    // Ctrl+Del: on paren delete the whole sexp; else delete word right
                    if (cursor < buf.length()) {
                        char c = buf.charAt(cursor);
                        if (c == '(' || c == ')' || c == '[' || c == ']') {
                            int[] r = SexpScanner.sexpRangeAt(buf, cursor);
                            if (r != null) {
                                buf.delete(r[0], r[1]);
                                cursor = r[0];
                                return true;
                            }
                        }
                    }
                    deleteWordRight();
                } else if (cursor < buf.length()) buf.deleteCharAt(cursor);
                return true;
            case LEFT:
                if (k.ctrl) {
                    if (cursor < buf.length()) {
                        char c = buf.charAt(cursor);
                        if (c == ')' || c == ']') {
                            int m = SexpScanner.matchingParen(buf, cursor);
                            if (m >= 0) { cursor = m; return true; }
                        }
                    }
                    if (cursor > 0) {
                        char c2 = buf.charAt(cursor - 1);
                        if (c2 == ')' || c2 == ']') {
                            int m = SexpScanner.matchingParen(buf, cursor - 1);
                            if (m >= 0) { cursor = m; return true; }
                        }
                    }
                    moveWordLeft();
                } else if (cursor > 0) cursor--;
                return true;
            case RIGHT:
                if (k.ctrl) {
                    if (cursor < buf.length()) {
                        char c = buf.charAt(cursor);
                        if (c == '(' || c == '[') {
                            int m = SexpScanner.matchingParen(buf, cursor);
                            if (m >= 0) { cursor = m + 1; return true; }
                        }
                    }
                    moveWordRight();
                } else if (cursor < buf.length()) cursor++;
                return true;
            case UP:
                // First logical row → history previous; else move within buffer
                if (logicalRowOfCursor() == 0) historyPrev();
                else moveCursorVertical(-1);
                return true;
            case DOWN:
                if (logicalRowOfCursor() == logicalLineCount() - 1) historyNext();
                else moveCursorVertical(+1);
                return true;
            case HOME:
                cursor = startOfLogicalLine(cursor); return true;
            case END:
                cursor = endOfLogicalLine(cursor); return true;
            case ESC:
                buf.setLength(0); cursor = 0; historyPos = history.size();
                return true;
            case CHAR:
                if (k.ctrl) return handleCtrl(k);
                if (k.alt) return true;
                if (k.ch == '\t') { tabComplete(); return true; }
                if (k.ch >= 0x20) {
                    buf.insert(cursor, (char) k.ch); cursor++;
                }
                return true;
            default:
                return true;
        }
    }

    private boolean handleCtrl(Key k) throws IOException {
        // k.ch is 'A'..'Z' (1..26 mapped to 64+)
        int code = k.ch;
        switch (code) {
            case 'A': cursor = startOfLogicalLine(cursor); return true;
            case 'E': cursor = endOfLogicalLine(cursor);   return true;
            case 'B': if (cursor > 0) cursor--; return true;
            case 'F': if (cursor < buf.length()) cursor++; return true;
            case 'K':
                buf.delete(cursor, endOfLogicalLine(cursor)); return true;
            case 'U':
                int s = startOfLogicalLine(cursor);
                buf.delete(s, cursor); cursor = s; return true;
            case 'W':
                int start = cursor;
                moveWordLeft();
                buf.delete(cursor, start);
                return true;
            case 'L':
                term.write("[2J[H");
                lastFrameRows = 0; lastFramePhysRow = 0;
                return true;
            case 'R':
                reverseSearch();
                return true;
            case 'D':
                if (cursor < buf.length()) { buf.deleteCharAt(cursor); return true; }
                if (buf.length() == 0) {
                    moveCursorToFrameBottom();
                    term.write("\n");
                    throw new IOException("EOF");
                }
                return true;
            default:
                return true;
        }
    }

    // ---------- history ----------

    private void historyPrev() {
        if (history.size() == 0) return;
        if (historyPos == history.size()) savedNewLine = buf.toString();
        if (historyPos > 0) {
            historyPos--;
            buf.setLength(0);
            buf.append(history.get(historyPos));
            cursor = buf.length();
        }
    }

    private void historyNext() {
        if (historyPos >= history.size()) return;
        historyPos++;
        buf.setLength(0);
        if (historyPos == history.size()) buf.append(savedNewLine);
        else buf.append(history.get(historyPos));
        cursor = buf.length();
    }

    // ---------- word motion ----------

    private void moveWordLeft() {
        while (cursor > 0 && !SexpScanner.isSymbolChar(buf.charAt(cursor - 1))) cursor--;
        while (cursor > 0 &&  SexpScanner.isSymbolChar(buf.charAt(cursor - 1))) cursor--;
    }
    private void moveWordRight() {
        int n = buf.length();
        while (cursor < n && !SexpScanner.isSymbolChar(buf.charAt(cursor))) cursor++;
        while (cursor < n &&  SexpScanner.isSymbolChar(buf.charAt(cursor))) cursor++;
    }
    private void deleteWordRight() {
        int start = cursor;
        moveWordRight();
        buf.delete(start, cursor);
        cursor = start;
    }

    // ---------- logical line geometry ----------

    private int startOfLogicalLine(int idx) {
        while (idx > 0 && buf.charAt(idx - 1) != '\n') idx--;
        return idx;
    }
    private int endOfLogicalLine(int idx) {
        int n = buf.length();
        while (idx < n && buf.charAt(idx) != '\n') idx++;
        return idx;
    }
    private int logicalRowOfCursor() {
        int r = 0;
        for (int i = 0; i < cursor; i++) if (buf.charAt(i) == '\n') r++;
        return r;
    }
    private int logicalLineCount() {
        int n = 1;
        for (int i = 0; i < buf.length(); i++) if (buf.charAt(i) == '\n') n++;
        return n;
    }
    private int columnOfCursor() {
        int c = (logicalRowOfCursor() == 0) ? visibleLength(prompt) : visibleLength(contIndent);
        int start = startOfLogicalLine(cursor);
        return c + (cursor - start);
    }

    private void moveCursorVertical(int delta) {
        int row = logicalRowOfCursor();
        int target = row + delta;
        if (target < 0 || target >= logicalLineCount()) return;
        int col = columnOfCursor();
        // Find start of target row
        int idx = 0;
        int r = 0;
        while (idx < buf.length() && r < target) {
            if (buf.charAt(idx) == '\n') r++;
            idx++;
        }
        int lineStart = idx;
        int lineEnd = endOfLogicalLine(idx);
        int rowIndent = (target == 0) ? visibleLength(prompt) : visibleLength(contIndent);
        int desiredOffset = Math.max(0, col - rowIndent);
        int actualOffset = Math.min(desiredOffset, lineEnd - lineStart);
        cursor = lineStart + actualOffset;
    }

    // ---------- completion ----------

    private void tabComplete() {
        int[] atom = SexpScanner.atomBefore(buf, cursor);
        if (atom == null) {
            // Insert literal tab? Many REPLs insert nothing when there's no atom.
            return;
        }
        String prefix = buf.substring(atom[0], atom[1]);
        List<String> cs = completions.completions(prefix);
        if (cs == null || cs.isEmpty()) {
            infoLineText = "(no completions)";
            lastInfoName = "";
            return;
        }
        if (cs.size() == 1) {
            replaceRange(atom[0], atom[1], cs.get(0));
            lastCompletions = null;
            return;
        }
        // Multiple: extend to common prefix
        String common = commonPrefix(cs);
        if (common.length() > prefix.length()) {
            replaceRange(atom[0], atom[1], common);
            lastCompletions = cs;
            return;
        }
        // Second tab → show list
        if (lastKeyWasTab && lastCompletions != null) {
            showCompletionList(lastCompletions);
            lastCompletions = null;
        } else {
            lastCompletions = cs;
            lastKeyWasTab = true;
        }
    }

    private void replaceRange(int start, int end, String repl) {
        buf.replace(start, end, repl);
        cursor = start + repl.length();
    }

    private void showCompletionList(List<String> cs) {
        moveCursorToFrameBottom();
        term.write("\n");
        int width = term.width();
        int maxLen = 0;
        for (String s : cs) maxLen = Math.max(maxLen, s.length());
        int colW = maxLen + 2;
        int cols = Math.max(1, width / colW);
        StringBuilder line = new StringBuilder();
        int i = 0;
        for (String s : cs) {
            line.append(s);
            for (int k = s.length(); k < colW; k++) line.append(' ');
            if ((++i) % cols == 0) { line.append('\n'); term.write(line.toString()); line.setLength(0); }
        }
        if (line.length() > 0) { line.append('\n'); term.write(line.toString()); }
        lastFrameRows = 0; lastFramePhysRow = 0;
    }

    private static String commonPrefix(List<String> ss) {
        String a = ss.get(0);
        int n = a.length();
        for (int i = 1; i < ss.size(); i++) {
            String b = ss.get(i);
            int m = Math.min(n, b.length());
            int j = 0;
            while (j < m && a.charAt(j) == b.charAt(j)) j++;
            n = j;
        }
        return a.substring(0, n);
    }

    // ---------- reverse search (Ctrl+R) ----------

    private void reverseSearch() throws IOException {
        StringBuilder q = new StringBuilder();
        int hit = -1;
        while (true) {
            String header = "(reverse-i-search)`" + q + "': ";
            String shown = (hit >= 0 ? history.get(hit) : "");
            // Render overlay as a single-line replacement of the prompt
            String oldPrompt = prompt;
            String oldContIndent = contIndent;
            StringBuilder oldBuf = new StringBuilder(buf);
            int oldCursor = cursor;
            prompt = header;
            StringBuilder pad = new StringBuilder();
            for (int i = 0; i < visibleLength(header); i++) pad.append(' ');
            contIndent = pad.toString();
            buf.setLength(0); buf.append(shown.replace('\n', ' '));
            cursor = buf.length();
            redrawNoInfo();
            prompt = oldPrompt; contIndent = oldContIndent;
            Key k = keys.next();
            if (k.type == Key.Type.ENTER) {
                if (hit >= 0) {
                    buf.setLength(0); buf.append(history.get(hit)); cursor = buf.length();
                } else {
                    buf.setLength(0); buf.append(oldBuf); cursor = oldCursor;
                }
                return;
            }
            if (k.type == Key.Type.ESC || k.type == Key.Type.INTERRUPT) {
                buf.setLength(0); buf.append(oldBuf); cursor = oldCursor;
                return;
            }
            if (k.type == Key.Type.BACKSPACE) {
                if (q.length() > 0) q.deleteCharAt(q.length() - 1);
                hit = history.searchBackward(q.toString(), history.size());
                buf.setLength(0); buf.append(oldBuf); cursor = oldCursor;
                continue;
            }
            if (k.type == Key.Type.CHAR && k.ctrl && k.ch == 'R') {
                hit = history.searchBackward(q.toString(), hit < 0 ? history.size() : hit);
                buf.setLength(0); buf.append(oldBuf); cursor = oldCursor;
                continue;
            }
            if (k.type == Key.Type.CHAR && !k.ctrl && !k.alt && k.ch >= 0x20) {
                q.append((char) k.ch);
                hit = history.searchBackward(q.toString(), history.size());
                buf.setLength(0); buf.append(oldBuf); cursor = oldCursor;
                continue;
            }
            // Other keys: cancel search and let the key be processed normally
            buf.setLength(0); buf.append(oldBuf); cursor = oldCursor;
            return;
        }
    }

    // ---------- info line ----------

    private void refreshInfo() {
        int[] atom = SexpScanner.atomAt(buf, cursor);
        String name = (atom == null) ? "" : buf.substring(atom[0], atom[1]);
        if (name.equals(lastInfoName)) return;
        lastInfoName = name;
        if (name.isEmpty()) { infoLineText = ""; return; }
        try {
            infoLineText = completions.infoLine(name);
            if (infoLineText == null) infoLineText = "";
        } catch (Exception ignored) {
            infoLineText = "";
        }
    }

    // ---------- redraw ----------

    private void redraw() { redrawImpl(true); }
    private void redrawNoInfo() { redrawImpl(false); }

    private void redrawImpl(boolean withInfo) {
        // Move to top of last frame
        if (lastFramePhysRow > 0) {
            term.write("[" + lastFramePhysRow + "A");
        }
        term.write("\r[J");

        int width = Math.max(20, term.width());

        // Determine the two indices (if any) to render in reverse video.
        // When the cursor sits on a paren, both that paren and its match are highlighted.
        // We also accept "cursor just past a closing paren" (cursor-1) as a hint,
        // since that's where the cursor naturally lands after typing it.
        int hi1 = -1, hi2 = -1;
        if (cursor < buf.length()) {
            char c = buf.charAt(cursor);
            if (c == '(' || c == ')' || c == '[' || c == ']') {
                int m = SexpScanner.matchingParen(buf, cursor);
                if (m >= 0) { hi1 = cursor; hi2 = m; }
            }
        }
        if (hi1 < 0 && cursor > 0) {
            char c = buf.charAt(cursor - 1);
            if (c == ')' || c == ']') {
                int m = SexpScanner.matchingParen(buf, cursor - 1);
                if (m >= 0) { hi1 = cursor - 1; hi2 = m; }
            }
        }

        // Build content with continuation lines and track physical rows.
        StringBuilder out = new StringBuilder();
        int physRow = 0;
        int physCol = 0;
        int cursorPhysRow = 0;
        int cursorPhysCol = 0;
        out.append(prompt);
        physCol = visibleLength(prompt);

        for (int i = 0; i <= buf.length(); i++) {
            if (i == cursor) {
                cursorPhysRow = physRow;
                cursorPhysCol = physCol;
            }
            if (i == buf.length()) break;
            char c = buf.charAt(i);
            if (c == '\n') {
                out.append('\n');
                out.append(contIndent);
                physRow++;
                physCol = visibleLength(contIndent);
            } else {
                if (i == hi1 || i == hi2) {
                    out.append("[7m").append(c).append("[0m");
                } else {
                    out.append(c);
                }
                physCol++;
                if (physCol >= width) {
                    physRow++;
                    physCol = 0;
                }
            }
        }

        // Info line
        if (withInfo && !infoLineText.isEmpty()) {
            out.append('\n');
            String info = infoLineText;
            if (visibleLength(info) > width - 1) info = info.substring(0, Math.max(0, width - 4)) + "...";
            out.append("[2m").append(info).append("[0m");
            physRow++;
        }

        term.write(out.toString());

        // Now physical cursor is at end of last drawn row. Move it to cursor target.
        // Steps: figure out current phys position (we approximate as end of frame: row=physRow, col=lastVisible).
        int endRow = physRow;
        // Move up to cursor row
        int up = endRow - cursorPhysRow;
        if (up > 0) term.write("[" + up + "A");
        term.write("\r");
        if (cursorPhysCol > 0) term.write("[" + cursorPhysCol + "C");

        lastFrameRows = physRow + 1;
        lastFramePhysRow = cursorPhysRow;
    }

    private void moveCursorToFrameBottom() {
        int down = (lastFrameRows - 1) - lastFramePhysRow;
        if (down > 0) term.write("[" + down + "B");
        term.write("\r");
        lastFrameRows = 0;
        lastFramePhysRow = 0;
    }

    /** Visible length, ignoring ANSI escape sequences. */
    private static int visibleLength(String s) {
        int n = 0;
        boolean inEsc = false;
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (inEsc) {
                if ((c >= 0x40 && c <= 0x7e)) inEsc = false;
                continue;
            }
            if (c == 0x1b) { inEsc = true; continue; }
            if (c >= 0x20) n++;
        }
        return n;
    }
}
