using System.Net.Sockets;
using System.IO;

namespace scheme;

public class SchemeSocket
{
    public TcpClient client;
    public TextStream inputPort;
    public TextOutputStream outputPort;
    public Stream networkStream;
    public BinaryInputStream? binaryInputPort;
    public BinaryOutputStream? binaryOutputPort;

    public SchemeSocket(TcpClient client)
    {
        this.client = client;
        this.networkStream = client.GetStream();
        this.inputPort = new TextStream(new StreamReader(networkStream), "{socket}");
        this.outputPort = new TextOutputStream(new StreamWriter(networkStream) { AutoFlush = false });
    }

    public SchemeSocket(TcpClient client, Stream stream)
    {
        this.client = client;
        this.networkStream = stream;
        this.inputPort = new TextStream(new StreamReader(stream), "{socket}");
        this.outputPort = new TextOutputStream(new StreamWriter(stream) { AutoFlush = false });
    }

    public override string ToString() => "#<socket>";
}
