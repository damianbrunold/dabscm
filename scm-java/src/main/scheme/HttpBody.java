package scheme;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;

// Reads the body of an HTTP request for tcp-http-serve: Content-Length
// bytes, or a Transfer-Encoding: chunked body. Bodies up to the spool
// threshold stay in memory; larger ones go to a temporary file, so a
// large upload does not need its size in memory. The caller deletes the
// file when the request is done.
public final class HttpBody {
    public byte[] bytes;   // the body, if kept in memory
    public Path file;      // the body, if spooled
    public long size;
    public boolean tooLarge;
    public boolean malformed;

    private final long maxBody;
    private final long spoolThreshold;
    private ByteArrayOutputStream mem = new ByteArrayOutputStream();
    private OutputStream fileOut;

    private HttpBody(long maxBody, long spoolThreshold) {
        this.maxBody = maxBody;
        this.spoolThreshold = spoolThreshold;
    }

    // length: the Content-Length, or -1 for a chunked body.
    public static HttpBody read(InputStream in, long length, long maxBody, long spoolThreshold)
            throws IOException {
        HttpBody b = new HttpBody(maxBody, spoolThreshold);
        try {
            if (length >= 0) b.readFixed(in, length);
            else b.readChunked(in);
        } finally {
            b.finish();
        }
        return b;
    }

    private void append(byte[] buf, int n) throws IOException {
        if (size + n > maxBody) {
            tooLarge = true;
            return;
        }
        if (fileOut == null && size + n > spoolThreshold) {
            file = Files.createTempFile("scm-http-", ".body");
            fileOut = Files.newOutputStream(file);
            mem.writeTo(fileOut);
            mem = null;
        }
        if (fileOut != null) fileOut.write(buf, 0, n);
        else mem.write(buf, 0, n);
        size += n;
    }

    private void readFixed(InputStream in, long length) throws IOException {
        byte[] buf = new byte[65536];
        long left = length;
        while (left > 0 && !tooLarge) {
            int r = in.read(buf, 0, (int) Math.min(buf.length, left));
            if (r <= 0) break; // client closed early: keep what arrived
            append(buf, r);
            left -= r;
        }
    }

    private static String readLine(InputStream in) throws IOException {
        StringBuilder sb = new StringBuilder();
        for (;;) {
            int c = in.read();
            if (c < 0) return null;
            if (c == '\n') break;
            if (c != '\r') sb.append((char) c);
            if (sb.length() > 4096) return null;
        }
        return sb.toString();
    }

    private void readChunked(InputStream in) throws IOException {
        byte[] buf = new byte[65536];
        for (;;) {
            String line = readLine(in);
            if (line == null) { malformed = true; return; }
            int semi = line.indexOf(';');
            String hex = (semi >= 0 ? line.substring(0, semi) : line).trim();
            long n;
            try { n = Long.parseLong(hex, 16); }
            catch (NumberFormatException e) { malformed = true; return; }
            if (n < 0) { malformed = true; return; }
            if (n == 0) {
                // Trailer fields, up to an empty line.
                for (;;) {
                    String t = readLine(in);
                    if (t == null || t.isEmpty()) return;
                }
            }
            if (size + n > maxBody) { tooLarge = true; return; }
            long left = n;
            while (left > 0) {
                int r = in.read(buf, 0, (int) Math.min(buf.length, left));
                if (r <= 0) { malformed = true; return; }
                append(buf, r);
                left -= r;
            }
            String crlf = readLine(in);
            if (crlf == null || !crlf.isEmpty()) { malformed = true; return; }
        }
    }

    private void finish() throws IOException {
        if (fileOut != null) fileOut.close();
        if (tooLarge || malformed) {
            discard();
            return;
        }
        if (file == null) bytes = mem.toByteArray();
    }

    public void discard() {
        if (file != null) {
            try { Files.deleteIfExists(file); } catch (IOException ignored) {}
        }
    }
}
