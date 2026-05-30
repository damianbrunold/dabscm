package scheme;

import java.io.File;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Windows extended-length path helpers and nio Path construction.
 *
 * On Windows, java.nio.file APIs accept the \\?\ (or \\?\UNC\) extended-length
 * prefix to bypass the legacy MAX_PATH (260 char) limit. java.io.File does NOT
 * (it normalizes the prefix away), which is why the fs primitives are built on
 * java.nio.file.Path. Off Windows these helpers are no-ops, so behaviour on
 * Linux/macOS is unchanged.
 */
public final class LongPath {
    private LongPath() {}

    private static final boolean WINDOWS =
        System.getProperty("os.name", "").toLowerCase().contains("windows");

    /**
     * Prefix an absolute path with \\?\ on Windows so it bypasses MAX_PATH.
     * No-op off Windows, on empty input, or when already prefixed.
     */
    public static String wlp(String path) {
        if (!WINDOWS || path == null || path.isEmpty()) return path;
        if (path.startsWith("\\\\?\\")) return path;
        String abs = new File(path).getAbsolutePath();
        if (abs.startsWith("\\\\")) return "\\\\?\\UNC\\" + abs.substring(2);
        return "\\\\?\\" + abs;
    }

    /**
     * Inverse of {@link #wlp}: strip a \\?\ extended-length prefix if present,
     * so the prefix never leaks into strings handed back to Scheme. No-op off
     * Windows or on empty input.
     */
    public static String strip(String path) {
        if (!WINDOWS || path == null || path.isEmpty()) return path;
        if (path.startsWith("\\\\?\\UNC\\")) return "\\\\" + path.substring(8);
        if (path.startsWith("\\\\?\\")) return path.substring(4);
        return path;
    }

    /**
     * Build a nio Path from a Scheme path string, applying the long-path
     * prefix on Windows. Use this everywhere instead of new File(s).toPath().
     */
    public static Path of(String path) {
        return Paths.get(wlp(path));
    }
}
