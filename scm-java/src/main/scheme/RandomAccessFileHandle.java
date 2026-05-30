package scheme;

import java.io.IOException;
import java.io.RandomAccessFile;

// Backing object for the (scm random access) primitives. Wraps a
// java.io.RandomAccessFile so Scheme code can do positioned (offset-explicit)
// reads and writes — the foundation for on-disk indexed stores that must not
// load a whole file into memory. Unlike the sequential BinaryInputStream/
// BinaryOutputStream ports (which buffer over a non-seekable InputStream),
// every operation here names its byte offset, so a single handle serves
// random access without a separate cursor.
public class RandomAccessFileHandle {
    private final RandomAccessFile raf;
    public final String path;
    public boolean isOpen = true;

    public RandomAccessFileHandle(RandomAccessFile raf, String path) {
        this.raf = raf;
        this.path = path;
    }

    private void ensureOpen(String who) {
        if (!isOpen) throw new SchemeError(who + ": random-access file is closed");
    }

    // Read up to count bytes starting at byte offset. Returns the bytes
    // actually read (fewer than count, possibly zero, when the read runs
    // into end of file).
    public byte[] read(long offset, int count) throws IOException {
        ensureOpen("random-access-file-read");
        if (count <= 0) return new byte[0];
        long size = raf.length();
        if (offset >= size) return new byte[0];
        int toRead = (int) Math.min((long) count, size - offset);
        byte[] buf = new byte[toRead];
        raf.seek(offset);
        int total = 0;
        while (total < toRead) {
            int n = raf.read(buf, total, toRead - total);
            if (n <= 0) break;
            total += n;
        }
        if (total < toRead) {
            byte[] shorter = new byte[total];
            System.arraycopy(buf, 0, shorter, 0, total);
            return shorter;
        }
        return buf;
    }

    // Write bv[start..end) at byte offset, extending the file when offset+len
    // is past the current end. Returns the number of bytes written.
    public int write(long offset, byte[] bv, int start, int end) throws IOException {
        ensureOpen("random-access-file-write!");
        int len = end - start;
        if (len <= 0) return 0;
        raf.seek(offset);
        raf.write(bv, start, len);
        return len;
    }

    public long size() throws IOException {
        ensureOpen("random-access-file-size");
        return raf.length();
    }

    public void truncate(long size) throws IOException {
        ensureOpen("random-access-file-truncate!");
        raf.setLength(size);
    }

    public void flush() throws IOException {
        ensureOpen("random-access-file-flush");
        raf.getFD().sync();
    }

    public void close() throws IOException {
        if (isOpen) {
            isOpen = false;
            raf.close();
        }
    }

    // Extract a handle from a primitive argument, raising a clear error when
    // the argument is not a random-access file handle.
    public static RandomAccessFileHandle of(SourcePos pos, Object arg, String who) {
        if (Value.isNativeValue(arg) && Value.asNativeValue(arg).value instanceof RandomAccessFileHandle)
            return (RandomAccessFileHandle) Value.asNativeValue(arg).value;
        throw new SchemeError(pos, who + ": random-access file handle expected, got ~s", arg);
    }
}
