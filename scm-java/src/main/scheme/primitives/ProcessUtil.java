package scheme.primitives;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

import scheme.Pair;
import scheme.Value;

/**
 * Helpers for launching external programs in a way that matches the C#
 * implementation across platforms.
 *
 * On Windows, CreateProcess (used by ProcessBuilder) can only launch real
 * executables (.exe/.com); it cannot run .bat/.cmd batch scripts found via
 * PATH/PATHEXT. So for run-program, run-program/capture and start-program we
 * detect when the requested program resolves to a batch script and rewrite
 * the command to run through "cmd.exe /c". The C# implementation does the
 * same in ProcUtil.CreateStartInfo.
 */
final class ProcessUtil {
    // The current directory as set-current-directory! sets it (the JVM
    // cannot change its process's directory: user.dir), for a child's
    // working directory; a relative 'work-dir is taken from there too
    static java.io.File workDir(String dir) {
        java.io.File cwd = new java.io.File(System.getProperty("user.dir"));
        if (dir == null) return cwd;
        java.io.File f = new java.io.File(dir);
        return f.isAbsolute() ? f : new java.io.File(cwd, dir);
    }

    private ProcessUtil() {}

    /**
     * Applies the optional 'env option to a ProcessBuilder. The value is an
     * alist of (name value) or (name . value) pairs of strings; each is added
     * to (or overrides) the child's inherited environment. Absent / NIL is a
     * no-op. Used by run-program, run-program/capture and start-program so
     * callers can pass e.g. PGPASSWORD or a server URL to a child (and, since
     * children inherit the augmented environment, transitively to its own
     * children).
     */
    static void applyEnv(ProcessBuilder pb, Object options) {
        Object env = PrimitiveGetProperty.getProperty(options, "env", Value.F);
        if (env == Value.F || env == Value.NIL) return;
        Object p = env;
        while (p != Value.NIL) {
            Pair entry = Value.asPair(p);
            Pair kv = Value.asPair(entry.car);
            String name = new String(Value.asString(kv.car));
            Object v = kv.cdr;
            String value = Value.isPair(v)
                ? new String(Value.asString(Value.asPair(v).car))
                : new String(Value.asString(v));
            pb.environment().put(name, value);
            p = entry.cdr;
        }
    }

    /**
     * The redirection options of run-program and start-program: 'stdin
     * <string> (returned, for feedStdin), 'stdin-file <path>, 'stdout
     * <path>, 'stderr <path> or 'stdout, 'append #t. Streams no option
     * names are left as the caller set them.
     */
    static String applyRedirects(ProcessBuilder pb, Object options) {
        if (options == Value.NIL) return null;
        boolean append = PrimitiveGetProperty.getProperty(options, "append", Value.F) != Value.F;
        String text = null;
        Object v = PrimitiveGetProperty.getProperty(options, "stdin", Value.F);
        if (v != Value.F) {
            text = new String(Value.asString(v));
            pb.redirectInput(ProcessBuilder.Redirect.PIPE);
        }
        v = PrimitiveGetProperty.getProperty(options, "stdin-file", Value.F);
        if (v != Value.F) {
            pb.redirectInput(scheme.SchemePaths.file(new String(Value.asString(v))));
        }
        v = PrimitiveGetProperty.getProperty(options, "stdout", Value.F);
        if (v != Value.F) {
            pb.redirectOutput(output(new String(Value.asString(v)), append));
        }
        v = PrimitiveGetProperty.getProperty(options, "stderr", Value.F);
        if (Value.isSymbol(v) && Value.asSymbol(v).equals("stdout")) {
            pb.redirectErrorStream(true);
        } else if (v != Value.F) {
            pb.redirectError(output(new String(Value.asString(v)), append));
        }
        return text;
    }

    static ProcessBuilder.Redirect output(String path, boolean append) {
        File f = scheme.SchemePaths.file(path);
        return append ? ProcessBuilder.Redirect.appendTo(f) : ProcessBuilder.Redirect.to(f);
    }

    /** Writes text (UTF-8) into the child's stdin and closes it, on a thread of its own */
    static void feedStdin(Process process, String text) {
        if (text == null) return;
        Thread t = new Thread(() -> {
            try (var out = process.getOutputStream()) {
                out.write(text.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            } catch (java.io.IOException ignored) {
                // the child did not read all of it
            }
        }, "scm-stdin-feeder");
        t.setDaemon(true);
        t.start();
    }

    /**
     * The command line for start-program's 'new-group #t: on POSIX the
     * program runs in a process group of its own, so that Ctrl+C at the
     * terminal does not reach it (perl's setpgrp, else setsid, before the
     * exec: the pid stays the program's). The JVM cannot do this on
     * Windows: there the command line is returned unchanged.
     */
    static List<String> newGroupCommand(List<String> argv) {
        if (isWindows()) return argv;
        String prog = argv.get(0);
        if (!hasPathSeparator(prog) && findExecutable(prog) == null
            || hasPathSeparator(prog) && !new File(prog).canExecute())
            throw new IllegalArgumentException("Cannot run program \"" + prog + "\": not found");
        List<String> out = new ArrayList<>();
        if (findExecutable("perl") != null) {
            out.add("perl");
            out.add("-e");
            out.add("setpgrp(0, 0); exec { $ARGV[0] } @ARGV; print STDERR \"$ARGV[0]: $!\\n\"; exit 127");
            out.add("--");
        } else if (findExecutable("setsid") != null) {
            out.add("setsid");
        } else {
            throw new IllegalArgumentException("'new-group needs perl or setsid");
        }
        out.addAll(argv);
        return out;
    }

    private static File findExecutable(String prog) {
        String path = System.getenv("PATH");
        if (path == null) return null;
        for (String dir : path.split(File.pathSeparator)) {
            if (dir.isEmpty()) continue;
            File f = new File(dir, prog);
            if (f.isFile() && f.canExecute()) return f;
        }
        return null;
    }

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
