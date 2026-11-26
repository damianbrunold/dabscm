package scheme;

/**
 * A small block of heap set aside so an OutOfMemoryError can still be
 * turned into a Scheme error and handled. When the heap runs out, the
 * data that filled it is usually still reachable while the handler runs
 * (the stack of the failed computation, the guard's continuation), so
 * the handler would fail again at its first allocation. Releasing the
 * reserve gives it room to build the condition, log and mark a job
 * failed. A daemon thread allocates the reserve again once the heap has
 * room for it, so a later OutOfMemoryError is handled the same way.
 */
final class MemoryReserve {
    /** heap/64, at least 1 MB and at most 16 MB. */
    private static final int SIZE = (int) Math.max(1L << 20,
        Math.min(16L << 20, Runtime.getRuntime().maxMemory() / 64));

    private static volatile byte[] reserve = allocate();
    private static Thread refiller;

    /** The exception text when not even the condition could be built. */
    static final String MESSAGE = "out of memory: raise the JVM heap (-Xmx)";

    private MemoryReserve() {}

    /** Loads the class (and takes the reserve) before the heap runs out. */
    static void init() {}

    private static byte[] allocate() {
        try {
            return new byte[SIZE];
        } catch (OutOfMemoryError e) {
            return null;
        }
    }

    /** Frees the reserve (if still held) and schedules its refill. */
    static void release() {
        if (reserve == null) return;
        reserve = null;
        startRefiller();
    }

    private static synchronized void startRefiller() {
        if (refiller != null && refiller.isAlive()) return;
        try {
            refiller = new Thread(() -> {
                long wait = 1000;
                while (reserve == null) {
                    try {
                        Thread.sleep(wait);
                    } catch (InterruptedException e) {
                        return;
                    }
                    reserve = allocate();
                    wait = Math.min(wait * 2, 60_000);
                }
            }, "scm-memory-reserve");
            refiller.setDaemon(true);
            refiller.start();
        } catch (Throwable t) {
            // no thread now: the next release tries again
            refiller = null;
        }
    }
}
