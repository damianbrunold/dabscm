namespace scheme;

public class BinaryInputStream
{
    private Stream stream;
    private int peeked = -2; // -2 = no peek buffered, -1 = EOF
    public bool IsOpen { get; private set; } = true;

    public BinaryInputStream(Stream stream)
    {
        this.stream = stream;
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
