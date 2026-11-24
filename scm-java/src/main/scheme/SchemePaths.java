package scheme;

import java.io.File;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Resolves relative Scheme paths against the current directory.
 *
 * set-current-directory! only changes the user.dir property; java.io.File
 * and java.nio resolve relative paths against the directory the JVM started
 * in. Every primitive that accesses the file system with a path from Scheme
 * resolves it here first. Until the directory is changed, paths are
 * returned unchanged.
 */
public final class SchemePaths {
    private SchemePaths() {}

    // the directory relative paths resolve against in java.io and java.nio
    private static final String STARTUP_DIR = new File("").getAbsolutePath();

    /** The path resolved against user.dir, or path itself if no change is needed. */
    public static String resolve(String path) {
        if (path == null) return null;
        String userDir = System.getProperty("user.dir");
        if (userDir == null || userDir.equals(STARTUP_DIR)) return path;
        if (new File(path).isAbsolute()) return path;
        if (File.separatorChar == '\\') {
            // \a and /a are rooted on the current drive
            if (path.startsWith("\\") || path.startsWith("/")) {
                Path root = new File(userDir).toPath().getRoot();
                return root == null ? path : new File(root.toString(), path.substring(1)).getPath();
            }
            // C:a is relative to that drive's directory, which is not tracked
            if (path.length() >= 2 && path.charAt(1) == ':') return path;
        }
        if (path.isEmpty()) return userDir;
        return new File(userDir, path).getPath();
    }

    public static File file(String path) {
        return new File(resolve(path));
    }

    public static Path path(String path) {
        return Paths.get(resolve(path));
    }
}
