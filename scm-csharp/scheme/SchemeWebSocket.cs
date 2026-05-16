using System.Net.Sockets;

namespace scheme;

public class SchemeWebSocket
{
    public NetworkStream stream;
    public bool IsServer;

    public SchemeWebSocket(NetworkStream stream, bool isServer)
    {
        this.stream = stream;
        this.IsServer = isServer;
    }

    public override string ToString() => "#<websocket>";
}
