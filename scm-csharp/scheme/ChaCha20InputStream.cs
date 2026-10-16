namespace scheme;

// Endless ChaCha20 keystream (20 rounds, the original 64-bit block counter
// and 64-bit nonce layout, nonce fixed at zero). Backs the deterministic
// random ports of (srfi 271 determinized). For block counters < 2^32 the
// output equals RFC 8439 ChaCha20 with an all-zero nonce.
//
// The position is (Counter, Offset): the next byte returned is byte
// Offset (0..63) of keystream block Counter. It is exact as long as the
// stream is read unbuffered, which is why BinaryInputStream must not wrap it.
public class ChaCha20InputStream : Stream
{
    private readonly byte[] key;
    private readonly uint[] input = new uint[16];
    private readonly uint[] x = new uint[16];
    private readonly byte[] block = new byte[64];

    public long Counter { get; private set; }
    public int Offset { get; private set; }

    public ChaCha20InputStream(byte[] key, long counter, int offset)
    {
        if (key.Length != 32)
            throw new SchemeError("chacha20: key must be 32 bytes");
        if (offset < 0 || offset > 63)
            throw new SchemeError("chacha20: offset must be in 0..63");
        this.key = (byte[])key.Clone();
        input[0] = 0x61707865;
        input[1] = 0x3320646e;
        input[2] = 0x79622d32;
        input[3] = 0x6b206574;
        for (int i = 0; i < 8; i++)
        {
            input[4 + i] = key[4 * i]
                | (uint)key[4 * i + 1] << 8
                | (uint)key[4 * i + 2] << 16
                | (uint)key[4 * i + 3] << 24;
        }
        Counter = counter;
        Offset = offset;
        GenerateBlock();
    }

    public byte[] Key => (byte[])key.Clone();

    private static uint Rotl(uint v, int c) => (v << c) | (v >> (32 - c));

    private void QuarterRound(int a, int b, int c, int d)
    {
        x[a] += x[b]; x[d] = Rotl(x[d] ^ x[a], 16);
        x[c] += x[d]; x[b] = Rotl(x[b] ^ x[c], 12);
        x[a] += x[b]; x[d] = Rotl(x[d] ^ x[a], 8);
        x[c] += x[d]; x[b] = Rotl(x[b] ^ x[c], 7);
    }

    private void GenerateBlock()
    {
        input[12] = (uint)Counter;
        input[13] = (uint)((ulong)Counter >> 32);
        input[14] = 0;
        input[15] = 0;
        Array.Copy(input, x, 16);
        for (int i = 0; i < 10; i++)
        {
            QuarterRound(0, 4, 8, 12);
            QuarterRound(1, 5, 9, 13);
            QuarterRound(2, 6, 10, 14);
            QuarterRound(3, 7, 11, 15);
            QuarterRound(0, 5, 10, 15);
            QuarterRound(1, 6, 11, 12);
            QuarterRound(2, 7, 8, 13);
            QuarterRound(3, 4, 9, 14);
        }
        for (int i = 0; i < 16; i++)
        {
            uint v = x[i] + input[i];
            block[4 * i] = (byte)v;
            block[4 * i + 1] = (byte)(v >> 8);
            block[4 * i + 2] = (byte)(v >> 16);
            block[4 * i + 3] = (byte)(v >> 24);
        }
    }

    private void Advance(int n)
    {
        Offset += n;
        if (Offset == 64)
        {
            Counter++;
            Offset = 0;
            GenerateBlock();
        }
    }

    public override int ReadByte()
    {
        int b = block[Offset];
        Advance(1);
        return b;
    }

    public override int Read(byte[] buffer, int offset, int count)
    {
        int done = 0;
        while (done < count)
        {
            int n = Math.Min(count - done, 64 - Offset);
            Array.Copy(block, Offset, buffer, offset + done, n);
            done += n;
            Advance(n);
        }
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
