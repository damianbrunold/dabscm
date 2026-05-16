package scheme;

import java.net.ServerSocket;
import java.util.concurrent.Semaphore;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.ExecutorService;

public class SchemeServer {
    public AtomicBoolean running = new AtomicBoolean(true);
    public Thread thread;
    public ExecutorService executor;
    public ServerSocket serverSocket;
    public Semaphore sem;
    public int maxThreads;
    public int gracefulStopMs;

    public SchemeServer(Thread t) {
        this.thread = t;
    }

    @Override
    public String toString() { return "#<server>"; }
}
