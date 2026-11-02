using System.Diagnostics;

namespace scheme;

// A read-only view of a socket stream with an overall deadline. The socket's
// ReceiveTimeout only bounds each read, so a client sending a byte every
// few seconds would otherwise hold a server thread for as long as it likes
// (slowloris). tcp-http-serve gives the request head read-timeout-ms in
// total and the body read-timeout-ms plus its size at MinBodyRate. Same as
// DeadlineInputStream.java.
public sealed class DeadlineStream : Stream
{
    // Slowest average body upload accepted, in bytes per second.
    public const long MinBodyRate = 16 * 1024;

    private readonly Stream inner;
    private long deadlineTicks;

    public DeadlineStream(Stream inner, long timeoutMs)
    {
        this.inner = inner;
        ExtendMs(timeoutMs);
    }

    public void ExtendMs(long timeoutMs)
    {
        deadlineTicks = Stopwatch.GetTimestamp() + timeoutMs * Stopwatch.Frequency / 1000;
    }

    // The deadline for a body of length bytes (-1: unknown, up to maxBody).
    public void StartBody(long readTimeoutMs, long length, long maxBody)
    {
        long bytes = length >= 0 ? length : maxBody;
        ExtendMs(readTimeoutMs + bytes * 1000 / MinBodyRate);
    }

    private void Check()
    {
        if (Stopwatch.GetTimestamp() > deadlineTicks)
            throw new IOException("request not received in time");
    }

    public override int Read(byte[] buffer, int offset, int count)
    {
        Check();
        return inner.Read(buffer, offset, count);
    }

    public override int ReadByte()
    {
        Check();
        return inner.ReadByte();
    }

    public override bool CanRead => true;
    public override bool CanSeek => false;
    public override bool CanWrite => false;
    public override long Length => throw new NotSupportedException();
    public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
    public override void Flush() { }
    public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
    public override void SetLength(long value) => throw new NotSupportedException();
    public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
}
