package scheme.repl;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Persistent command history. Each entry is a full input string and may
 * contain newlines. The on-disk format is one entry per physical line,
 * with \n encoded as TAB+'n' and TAB encoded as TAB+'t' (the same trick
 * the dabshell editor uses to keep the file grep-friendly).
 */
public final class History {

    private static final int CAP = 1000;
    private final Path file;
    private final List<String> entries = new ArrayList<>();

    public History(Path file) {
        this.file = file;
        load();
    }

    public int size() { return entries.size(); }
    public String get(int i) { return entries.get(i); }
    public List<String> all() { return Collections.unmodifiableList(entries); }

    public void add(String entry) {
        if (entry == null || entry.isEmpty()) return;
        if (!entries.isEmpty() && entries.get(entries.size() - 1).equals(entry)) return;
        entries.add(entry);
        while (entries.size() > CAP) entries.remove(0);
        appendToFile(entry);
    }

    /** Search backwards from {@code from} (exclusive) for an entry containing q. */
    public int searchBackward(String q, int from) {
        if (q.isEmpty()) return from;
        int start = Math.min(from - 1, entries.size() - 1);
        for (int i = start; i >= 0; i--) {
            if (entries.get(i).contains(q)) return i;
        }
        return -1;
    }

    /** Search forward from {@code from} (exclusive). */
    public int searchForward(String q, int from) {
        if (q.isEmpty()) return -1;
        for (int i = Math.max(from + 1, 0); i < entries.size(); i++) {
            if (entries.get(i).contains(q)) return i;
        }
        return -1;
    }

    private void load() {
        if (file == null || !Files.exists(file)) return;
        try {
            for (String line : Files.readAllLines(file, StandardCharsets.UTF_8)) {
                entries.add(decode(line));
            }
            // Cap on load (in case file grew)
            while (entries.size() > CAP) entries.remove(0);
        } catch (IOException ignored) {}
    }

    private void appendToFile(String entry) {
        if (file == null) return;
        try {
            if (file.getParent() != null) Files.createDirectories(file.getParent());
            String line = encode(entry) + "\n";
            Files.write(file, line.getBytes(StandardCharsets.UTF_8),
                java.nio.file.StandardOpenOption.CREATE,
                java.nio.file.StandardOpenOption.APPEND);
        } catch (IOException ignored) {}
    }

    static String encode(String s) {
        StringBuilder sb = new StringBuilder(s.length() + 8);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '\n') sb.append('\t').append('n');
            else if (c == '\t') sb.append('\t').append('t');
            else sb.append(c);
        }
        return sb.toString();
    }

    static String decode(String s) {
        StringBuilder sb = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '\t' && i + 1 < s.length()) {
                char n = s.charAt(i + 1);
                if (n == 'n') { sb.append('\n'); i++; continue; }
                if (n == 't') { sb.append('\t'); i++; continue; }
            }
            sb.append(c);
        }
        return sb.toString();
    }
}
