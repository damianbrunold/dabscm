package scheme.primitives;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

/**
 * Helpers for launching external programs in a way that matches the C#
 * implementation across platforms.
 *
 * On Windows, Java's CreateProcess (used by ProcessBuilder) can only launch
 * real executables (.exe/.com); it cannot run .bat/.cmd batch scripts directly.
 * The C# Process class, on the other hand, resolves such scripts via PATH and
 * PATHEXT and launches them transparently. To keep run-program,
 * run-program/capture and start-program behaving identically in both
 * implementations, we detect when the requested program resolves to a batch
 * script and rewrite the command to run through "cmd.exe /c".
 */
final class ProcessUtil {
    private ProcessUtil() {}

    /**
     * Destroys a process and all of its descendants. Process.destroy() /
     * destroyForcibly() terminate only the direct child; on Windows that child
     * is often a wrapper (e.g. cmd.exe running scm.bat, which in turn spawns the
     * real JVM/server as a grandchild), so killing it alone leaves the
     * grandchild alive — still holding its listening port.
     *
     * This mirrors the Python original's psutil kill_proc_tree: snapshot the
     * whole descendant tree *while the root is still alive* (afterwards the
     * reported parent/child links vanish), then terminate every process via the
     * JDK's own native facility — ProcessHandle.destroy[Forcibly]() maps to
     * TerminateProcess on Windows and kill() on POSIX. Crucially it does NOT
     * shell out to "taskkill" (a separate executable an application-control
     * allowlist can block on locked-down Windows) and does NOT depend on a
     * Windows Job Object (assignment is refused when the process is already
     * job-contained, as security tooling often arranges). Per-pid TerminateProcess
     * is an in-process kernel call, which is exactly what worked under psutil.
     */
    static void destroyTree(Process process, boolean force) {
        // Snapshot children first, root last (psutil order): a child can't be
        // reparented onto a still-living ancestor we have not killed yet.
        List<ProcessHandle> tree =
            new ArrayList<>(process.descendants().collect(Collectors.toList()));
        tree.add(process.toHandle());
        destroyAll(tree, force);
        // Brief settle, then a second sweep over the same handles for anything
        // that survived the first signal (mirrors psutil's wait_procs follow-up).
        try { Thread.sleep(100); }
        catch (InterruptedException ie) { Thread.currentThread().interrupt(); }
        destroyAll(tree, true);
    }

    private static void destroyAll(List<ProcessHandle> handles, boolean force) {
        for (ProcessHandle h : handles) {
            if (!h.isAlive()) continue;
            try {
                if (force) h.destroyForcibly();
                else       h.destroy();
            } catch (Exception ignored) {}
        }
    }

    static boolean isWindows() {
        return System.getProperty("os.name", "")
            .toLowerCase(Locale.ROOT).contains("win");
    }

    /**
     * If, on Windows, argv's program resolves to a .bat/.cmd script, return a
     * new argument list that runs it through "cmd.exe /c". Otherwise (any other
     * platform, an .exe/.com program, or an unresolvable name) return argv
     * unchanged so ProcessBuilder handles it exactly as before.
     */
    static List<String> resolveBatchLauncher(List<String> argv) {
        if (!isWindows() || argv.isEmpty()) return argv;
        String batch = resolveBatch(argv.get(0));
        if (batch == null) return argv;
        List<String> out = new ArrayList<>(argv.size() + 2);
        out.add("cmd.exe");
        out.add("/c");
        out.add(batch);
        for (int i = 1; i < argv.size(); i++) out.add(argv.get(i));
        return out;
    }

    // Returns the full path of the program iff it resolves to a .bat/.cmd file,
    // honouring PATHEXT precedence so that a .exe/.com earlier in the search
    // order wins and suppresses wrapping. Returns null otherwise.
    private static String resolveBatch(String prog) {
        String lower = prog.toLowerCase(Locale.ROOT);
        if (lower.endsWith(".bat") || lower.endsWith(".cmd")) {
            File f = findOnPath(prog);
            return f != null ? f.getPath() : prog;
        }
        if (hasExtension(prog)) return null; // e.g. .exe — leave to ProcessBuilder.

        String[] exts = pathext();
        if (hasPathSeparator(prog)) {
            for (String ext : exts) {
                File f = new File(prog + ext);
                if (f.isFile()) return isBatch(ext) ? f.getPath() : null;
            }
            return null;
        }
        String path = System.getenv("PATH");
        if (path == null) return null;
        for (String dir : path.split(File.pathSeparator)) {
            if (dir.isEmpty()) continue;
            for (String ext : exts) {
                File f = new File(dir, prog + ext);
                if (f.isFile()) return isBatch(ext) ? f.getPath() : null;
            }
        }
        return null;
    }

    private static File findOnPath(String prog) {
        File direct = new File(prog);
        if (direct.isFile()) return direct;
        if (hasPathSeparator(prog)) return null;
        String path = System.getenv("PATH");
        if (path == null) return null;
        for (String dir : path.split(File.pathSeparator)) {
            if (dir.isEmpty()) continue;
            File f = new File(dir, prog);
            if (f.isFile()) return f;
        }
        return null;
    }

    private static String[] pathext() {
        String pe = System.getenv("PATHEXT");
        if (pe == null || pe.isEmpty()) pe = ".COM;.EXE;.BAT;.CMD";
        List<String> exts = new ArrayList<>();
        for (String e : pe.split(";")) {
            e = e.trim();
            if (!e.isEmpty()) exts.add(e);
        }
        return exts.toArray(new String[0]);
    }

    private static boolean isBatch(String ext) {
        return ext.equalsIgnoreCase(".bat") || ext.equalsIgnoreCase(".cmd");
    }

    private static boolean hasPathSeparator(String prog) {
        return prog.indexOf('\\') >= 0 || prog.indexOf('/') >= 0;
    }

    private static boolean hasExtension(String prog) {
        int slash = Math.max(prog.lastIndexOf('\\'), prog.lastIndexOf('/'));
        return prog.lastIndexOf('.') > slash;
    }
}
