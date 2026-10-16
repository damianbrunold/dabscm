using System.Security.Cryptography;

namespace scheme;

// Endless stream of cryptographically random bytes. Backs the random ports
// of (srfi 271 randomized).
public class SecureRandomInputStream : Stream
{
    public override int ReadByte()
    {
        Span<byte> b = stackalloc byte[1];
        RandomNumberGenerator.Fill(b);
        return b[0];
    }

    public override int Read(byte[] buffer, int offset, int count)
    {
        RandomNumberGenerator.Fill(buffer.AsSpan(offset, count));
        return count;
    }

    public override bool CanRead => true;
    public override bool CanSeek => false;
    public override bool CanWrite => false;
    public override long Length => throw new NotSupportedException();
    public override long Position
    {
        get => throw new NotSupportedException();
        set => throw new NotSupportedException();
    }
    public override void Flush() { }
    public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
    public override void SetLength(long value) => throw new NotSupportedException();
    public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
}
