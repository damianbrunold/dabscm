using System.Net.Sockets;

namespace scheme;

public class SchemeListener
{
    public TcpListener listener;

    public SchemeListener(TcpListener listener)
    {
        this.listener = listener;
    }

    public override string ToString() => "#<tcp-listener>";
}
