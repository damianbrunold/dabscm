using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;

namespace scheme;

public class SchemeServer
{
    public CancellationTokenSource cts;
    public Task task;
    public TcpListener listener;
    public SemaphoreSlim? sem;
    public int maxThreads;
    public int gracefulStopMs;

    public SchemeServer(CancellationTokenSource cts, Task task, TcpListener listener)
    {
        this.cts = cts;
        this.task = task;
        this.listener = listener;
    }

    public override string ToString() => "#<server>";
}
