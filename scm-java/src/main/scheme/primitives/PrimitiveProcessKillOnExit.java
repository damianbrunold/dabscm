package scheme.primitives;
import scheme.*;
import java.util.Set;
import java.util.concurrent.CopyOnWriteArraySet;
import java.util.concurrent.atomic.AtomicBoolean;

public class PrimitiveProcessKillOnExit extends Primitive {
    // Children registered to be killed when this process exits. Shared across
    // all calls so a single JVM shutdown hook suffices.
    private static final Set<Process> TRACKED = new CopyOnWriteArraySet<>();
    private static final AtomicBoolean HOOK_INSTALLED = new AtomicBoolean(false);

    @Override
    public String name() { return "process-kill-on-exit"; }

    @Override
    public String info() {
        return "Syntax: (process-kill-on-exit handle)\n" +
               "Library: (scm system)\n" +
               "Description: Registers a process started by start-program to be killed " +
               "forcefully when this (parent) process exits, via a JVM shutdown hook fired " +
               "on SIGINT, SIGTERM, SIGHUP and normal exit. Prevents orphaned children — " +
               "e.g. a dev supervisor's server child left holding a port after the " +
               "supervisor is stopped. Already-exited handles are pruned, so the registry " +
               "stays bounded across repeated restarts. Returns #t.\n" +
               "Example:\n" +
               "  (define p (start-program '(\"scm\" \"server.scm\")))\n" +
               "  (process-kill-on-exit p)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeProcess sp = (SchemeProcess) Value.asNativeValue(arguments[0]).value;
        // Prune dead entries so the set stays bounded across many restarts.
        for (Process p : TRACKED) {
            if (!p.isAlive()) TRACKED.remove(p);
        }
        TRACKED.add(sp.process);
        if (HOOK_INSTALLED.compareAndSet(false, true)) {
            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                for (Process p : TRACKED) {
                    // Tree-kill: the tracked handle is often a wrapper whose
                    // grandchild holds the port (see ProcessUtil.destroyTree).
                    try { if (p.isAlive()) ProcessUtil.destroyTree(p, true); } catch (Exception ignored) {}
                }
            }));
        }
        return Value.T;
    }
}
