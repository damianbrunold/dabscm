namespace scheme;

public class BinaryInputStream
{
    private Stream stream;
    private int peeked = -2; // -2 = no peek buffered, -1 = EOF
    public bool IsOpen { get; private set; } = true;

    public BinaryInputStream(Stream stream)
    {
        // Wrap unbuffered streams (e.g. NetworkStream) with a buffer so
        // small reads — read-u8 in particular — don't pay a syscall /
        // managed↔native transition per byte. Wire-protocol parsers
        // (postgres, sqlserver) read length prefixes byte-by-byte and
        // are dominated by that overhead without buffering.
        if (stream is BufferedStream || stream is MemoryStream)
        {
            this.stream = stream;
        }
        else
        {
            this.stream = new BufferedStream(stream, 8192);
        }
    }

    public int ReadByte()
    {
        if (!IsOpen) throw new SchemeError("read-u8: port is closed");
        if (peeked != -2)
        {
            int val = peeked;
            peeked = -2;
            return val;
        }
        return stream.ReadByte();
    }

    // Bulk read: fills buf[offset..offset+count] from the stream, honouring
    // any peeked byte first. Returns the number of bytes actually read
    // (may be less than count near EOF; 0 means EOF).
    public int Read(byte[] buf, int offset, int count)
    {
        if (!IsOpen) throw new SchemeError("read-bytevector: port is closed");
        if (count == 0) return 0;
        int total = 0;
        if (peeked != -2)
        {
            if (peeked == -1) return 0;
            buf[offset] = (byte)peeked;
            peeked = -2;
            total = 1;
            if (count == 1) return 1;
        }
        while (total < count)
        {
            int n = stream.Read(buf, offset + total, count - total);
            if (n <= 0) break;
            total += n;
        }
        return total;
    }

    public int PeekByte()
    {
        if (!IsOpen) throw new SchemeError("peek-u8: port is closed");
        if (peeked == -2)
        {
            peeked = stream.ReadByte();
        }
        return peeked;
    }

    public void Close()
    {
        IsOpen = false;
        stream.Close();
    }
}
