using System.IO;

namespace scheme;

// Backing object for the (scm random-access) primitives. Wraps a seekable
// FileStream so Scheme code can do positioned (offset-explicit) reads and
// writes — the foundation for on-disk indexed stores that must not load a
// whole file into memory. Unlike the sequential BinaryInputStream/
// BinaryOutputStream ports, every operation names its byte offset, so a
// single handle serves random access without a separate cursor.
public class RandomAccessFileHandle
{
    private FileStream stream;
    public string Path { get; }
    public bool IsOpen { get; private set; } = true;

    public RandomAccessFileHandle(FileStream stream, string path)
    {
        this.stream = stream;
        this.Path = path;
    }

    // Extract a handle from a primitive argument, raising a clear error
    // when the argument is not a random-access file handle.
    public static RandomAccessFileHandle Of(SourcePos? pos, object arg, string who)
    {
        if (Value.IsNativeValue(arg) && Value.AsNativeValue(arg).value is RandomAccessFileHandle h)
            return h;
        throw new SchemeError(pos, who + ": random-access file handle expected, got ~s", arg);
    }

    private void EnsureOpen(string who)
    {
        if (!IsOpen) throw new SchemeError(who + ": random-access file is closed");
    }

    // Read up to count bytes starting at byte offset. Returns the bytes
    // actually read (fewer than count, possibly zero, when the read runs
    // into end of file).
    public byte[] Read(long offset, int count)
    {
        EnsureOpen("random-access-file-read");
        if (count <= 0) return new byte[0];
        long size = stream.Length;
        if (offset >= size) return new byte[0];
        int toRead = (int)System.Math.Min((long)count, size - offset);
        byte[] buf = new byte[toRead];
        stream.Seek(offset, SeekOrigin.Begin);
        int total = 0;
        while (total < toRead)
        {
            int n = stream.Read(buf, total, toRead - total);
            if (n <= 0) break;
            total += n;
        }
        if (total < toRead)
        {
            byte[] shorter = new byte[total];
            System.Array.Copy(buf, shorter, total);
            return shorter;
        }
        return buf;
    }

    // Write bv[start..end) at byte offset, extending the file when offset+len
    // is past the current end. Returns the number of bytes written.
    public int Write(long offset, byte[] bv, int start, int end)
    {
        EnsureOpen("random-access-file-write!");
        int len = end - start;
        if (len <= 0) return 0;
        stream.Seek(offset, SeekOrigin.Begin);
        stream.Write(bv, start, len);
        return len;
    }

    public long Size()
    {
        EnsureOpen("random-access-file-size");
        return stream.Length;
    }

    public void Truncate(long size)
    {
        EnsureOpen("random-access-file-truncate!");
        stream.SetLength(size);
    }

    public void Flush()
    {
        EnsureOpen("random-access-file-flush");
        stream.Flush(true);
    }

    public void Close()
    {
        if (IsOpen)
        {
            IsOpen = false;
            stream.Close();
        }
    }
}
