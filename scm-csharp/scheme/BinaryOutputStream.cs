namespace scheme;

public class BinaryOutputStream
{
    private Stream stream;
    private bool isBytevectorPort;
    public bool IsOpen { get; private set; } = true;

    public BinaryOutputStream(Stream stream, bool isBytevectorPort = false)
    {
        this.stream = stream;
        this.isBytevectorPort = isBytevectorPort;
    }

    public void WriteByte(byte b)
    {
        if (!IsOpen) throw new SchemeError("write-u8: port is closed");
        stream.WriteByte(b);
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
