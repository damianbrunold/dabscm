package scheme;

import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.SocketTimeoutException;

// A socket stream with an overall deadline. The socket's read timeout only
// bounds the wait for each read, so a client sending a byte every few
// seconds would otherwise hold a server thread for as long as it likes
// (slowloris). tcp-http-serve gives the request head read-timeout-ms in
// total and the body read-timeout-ms plus its size at MIN_BODY_RATE.
public final class DeadlineInputStream extends FilterInputStream {
    // Slowest average body upload accepted, in bytes per second.
    public static final long MIN_BODY_RATE = 16 * 1024;

    private long deadlineNanos;

    public DeadlineInputStream(InputStream in, long timeoutMs) {
        super(in);
        extendMs(timeoutMs);
    }

    // A new deadline timeoutMs from now.
    public void extendMs(long timeoutMs) {
        deadlineNanos = System.nanoTime() + timeoutMs * 1_000_000L;
    }

    // The deadline for a body of length bytes (-1: unknown, up to maxBody).
    public void startBody(long readTimeoutMs, long length, long maxBody) {
        long bytes = length >= 0 ? length : maxBody;
        extendMs(readTimeoutMs + bytes * 1000L / MIN_BODY_RATE);
    }

    private void check() throws IOException {
        if (System.nanoTime() - deadlineNanos > 0)
            throw new SocketTimeoutException("request not received in time");
    }

    @Override
    public int read() throws IOException {
        check();
        return super.read();
    }

    @Override
    public int read(byte[] b, int off, int len) throws IOException {
        check();
        return super.read(b, off, len);
    }
}
