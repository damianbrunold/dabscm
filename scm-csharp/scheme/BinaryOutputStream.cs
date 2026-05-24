namespace scheme;

public class BinaryOutputStream
{
    private Stream stream;
    private bool isBytevectorPort;
    public bool IsOpen { get; private set; } = true;

    public BinaryOutputStream(Stream stream, bool isBytevectorPort = false)
    {
        // Wrap unbuffered streams (e.g. NetworkStream) with a buffer so
        // byte-by-byte writes don't pay a syscall per byte. The wire-
        // protocol senders (postgres, sqlserver) build messages with
        // many small WriteByte calls; without buffering, multi-MB SQL
        // statements take tens of seconds to drain to the socket.
        // Bytevector ports (MemoryStream) and already-buffered streams
        // pass through.
        if (isBytevectorPort
                || stream is BufferedStream
                || stream is MemoryStream)
        {
            this.stream = stream;
        }
        else
        {
            this.stream = new BufferedStream(stream, 8192);
        }
        this.isBytevectorPort = isBytevectorPort;
    }

    public void WriteByte(byte b)
    {
        if (!IsOpen) throw new SchemeError("write-u8: port is closed");
        stream.WriteByte(b);
    }

    // Bulk write: forwards a contiguous chunk to the underlying stream
    // in one call. PrimitiveWriteBytevector uses this so multi-MB
    // payloads don't go through the per-byte path.
    public void Write(byte[] buf, int offset, int count)
    {
        if (!IsOpen) throw new SchemeError("write-bytevector: port is closed");
        stream.Write(buf, offset, count);
    }

    public void Flush()
    {
        if (!IsOpen) return;
        stream.Flush();
    }

    public byte[] GetBytes()
    {
        if (!isBytevectorPort)
            throw new SchemeError("get-output-bytevector: not a bytevector output port");
        if (stream is MemoryStream ms)
            return ms.ToArray();
        throw new SchemeError("get-output-bytevector: internal error");
    }

    public void Close()
    {
        IsOpen = false;
        stream.Close();
    }
}
