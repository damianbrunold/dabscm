package scheme.repl;

import java.io.IOException;
import java.io.InputStream;
import java.io.PrintStream;
import java.util.Locale;

/**
 * Minimal portable terminal driver for the dabscm REPL.
 *
 * On Unix-like systems we shell out to /bin/stty to put the controlling
 * terminal into a "character at a time" mode (icanon/echo off, but keep
 * opost so \n still expands to \r\n on output). On Windows we currently
 * return {@code canRaw() == false} — the cooked REPL fallback is used,
 * and the C# build is the recommended Windows REPL.
 *
 * The driver owns reading from System.in and writing ANSI escapes to
 * System.out. It deliberately holds no buffer state beyond a tiny
 * pushback for escape-sequence parsing.
 */
public final class Terminal {

    private final InputStream in = System.in;
    private final PrintStream out = System.out;
    private String savedStty;
    private boolean raw;
    private final boolean unix;
    private int pushback = -1;

    public Terminal() {
        String os = System.getProperty("os.name", "").toLowerCase(Locale.ROOT);
        this.unix = !os.contains("win");
    }

    /** True iff we believe we can enter raw mode in this process. */
    public boolean canRaw() {
        if (!unix) return false;
        if (System.console() == null) return false;
        String term = System.getenv("TERM");
        if (term == null || term.isEmpty() || term.equals("dumb")) return false;
        return sttyAvailable();
    }

    private static Boolean sttyCache;
    private static boolean sttyAvailable() {
        if (sttyCache != null) return sttyCache;
        try {
            Process p = new ProcessBuilder("/bin/stty", "-g")
                .redirectInput(ProcessBuilder.Redirect.INHERIT)
                .redirectError(ProcessBuilder.Redirect.DISCARD)
                .redirectOutput(ProcessBuilder.Redirect.PIPE)
                .start();
            p.getInputStream().readAllBytes();
            sttyCache = (p.waitFor() == 0);
        } catch (Exception e) {
            sttyCache = false;
        }
        return sttyCache;
    }

    /** Enter raw mode. Idempotent. Restores automatically on JVM shutdown. */
    public void enterRaw() throws IOException {
        if (raw || !canRaw()) return;
        savedStty = runStty("-g").trim();
        // -icanon: no line buffering; -echo: don't echo input; min 1 time 0: blocking single-char reads.
        // Keep opost so \n on output still gets \r\n, and isig so Ctrl+C still raises SIGINT (we'll intercept it ourselves).
        runStty("-icanon", "-echo", "min", "1", "time", "0");
        raw = true;
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            try { restore(); } catch (Exception ignored) {}
        }, "dabscm-tty-restore"));
    }

    public void restore() throws IOException {
        if (!raw || savedStty == null) return;
        runStty(savedStty);
        raw = false;
    }

    private String runStty(String... args) throws IOException {
        String[] cmd = new String[args.length + 1];
        cmd[0] = "/bin/stty";
        System.arraycopy(args, 0, cmd, 1, args.length);
        try {
            Process p = new ProcessBuilder(cmd)
                .redirectInput(ProcessBuilder.Redirect.INHERIT)
                .redirectError(ProcessBuilder.Redirect.DISCARD)
                .redirectOutput(ProcessBuilder.Redirect.PIPE)
                .start();
            byte[] bytes = p.getInputStream().readAllBytes();
            p.waitFor();
            return new String(bytes);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("stty interrupted", e);
        }
    }

    /** Read one byte (0..255), or -1 on EOF. Blocks. */
    public int readByte() throws IOException {
        if (pushback >= 0) { int b = pushback; pushback = -1; return b; }
        return in.read();
    }

    /** Read one byte non-blocking; -1 if nothing available. Best-effort: uses InputStream.available(). */
    public int peekByteIfAny() throws IOException {
        if (pushback >= 0) return pushback;
        if (in.available() > 0) {
            int b = in.read();
            pushback = b;
            return b;
        }
        return -1;
    }

    public void unread(int b) { pushback = b; }

    public void write(String s) {
        out.print(s);
        out.flush();
    }

    public void writeChar(char c) {
        out.print(c);
        out.flush();
    }

    /**
     * Terminal width in columns. Cached with a short TTL so that fast
     * redraws don't fork a stty subprocess on every keystroke, but a
     * resize is picked up within ~500 ms.
     */
    private int cachedWidth = 0;
    private long cachedWidthAt = 0L;

    public int width() {
        long now = System.currentTimeMillis();
        if (cachedWidth > 0 && (now - cachedWidthAt) < 500) return cachedWidth;
        int w = probeWidth();
        cachedWidth = w;
        cachedWidthAt = now;
        return w;
    }

    private int probeWidth() {
        try {
            String s = runStty("size").trim();
            String[] parts = s.split("\\s+");
            if (parts.length >= 2) {
                int cols = Integer.parseInt(parts[1]);
                if (cols > 0) return cols;
            }
        } catch (Exception ignored) {}
        String cols = System.getenv("COLUMNS");
        if (cols != null) try { int c = Integer.parseInt(cols); if (c > 0) return c; } catch (NumberFormatException ignored) {}
        return 80;
    }
}
