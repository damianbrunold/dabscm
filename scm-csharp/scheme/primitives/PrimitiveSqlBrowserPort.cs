using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;

namespace scheme;

public class PrimitiveSqlBrowserPort : Primitive
{
    public override string Name() => "sql-browser-port";

    public override string Info() =>
        "Syntax: (sql-browser-port host instance)\n" +
        "Syntax: (sql-browser-port host instance timeout-ms)\n" +
        "Library: (scm core)\n" +
        "Description: Asks the SQL Server Browser service on host (UDP 1434) for the TCP\n" +
        "  port of the named instance and returns it as an integer. Raises an error when\n" +
        "  the browser does not answer within timeout-ms (default 5000, two attempts) or\n" +
        "  the instance has no TCP endpoint. SCM_SQL_BROWSER_PORT overrides the UDP port\n" +
        "  (for tests).\n" +
        "Example:\n" +
        "  (sql-browser-port \"dbhost\" \"SQLEXPRESS\") ; => 49170";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        string host = new String(Value.AsString(arguments[0]));
        string instance = new String(Value.AsString(arguments[1]));
        int timeout = arguments.Length > 2 ? IntegerMath.ToInt(arguments[2]) : 5000;
        try
        {
            return (long) Lookup(host, instance, timeout);
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "sql-browser-port: " + e.Message);
        }
    }

    static int BrowserPort()
    {
        string? v = Environment.GetEnvironmentVariable("SCM_SQL_BROWSER_PORT");
        return string.IsNullOrWhiteSpace(v) ? 1434 : int.Parse(v.Trim());
    }

    // SSRP CLNT_UCAST_INST request; the reply is SVR_RESP 0x05, u16 LE size, then
    // "ServerName;S;InstanceName;I;IsClustered;No;Version;V;tcp;PORT;np;...;;"
    public static int Lookup(string host, string instance, int timeoutMs)
    {
        int udpPort = BrowserPort();
        byte[] name = Encoding.ASCII.GetBytes(instance);
        byte[] req = new byte[name.Length + 1];
        req[0] = 0x04;
        Array.Copy(name, 0, req, 1, name.Length);
        IPAddress[] addrs = Dns.GetHostAddresses(host);
        IPAddress addr = Array.Find(addrs, a => a.AddressFamily == AddressFamily.InterNetwork) ?? addrs[0];
        string? reply = null;
        using (var sock = new Socket(addr.AddressFamily, SocketType.Dgram, ProtocolType.Udp))
        {
            sock.ReceiveTimeout = Math.Max(1, timeoutMs / 2);
            var target = new IPEndPoint(addr, udpPort);
            for (int attempt = 0; attempt < 2 && reply == null; attempt++)
            {
                sock.SendTo(req, target);
                byte[] buf = new byte[65535];
                EndPoint from = new IPEndPoint(addr.AddressFamily == AddressFamily.InterNetwork
                    ? IPAddress.Any : IPAddress.IPv6Any, 0);
                int got;
                try
                {
                    got = sock.ReceiveFrom(buf, ref from);
                }
                catch (SocketException e) when (e.SocketErrorCode == SocketError.TimedOut
                                                || e.SocketErrorCode == SocketError.ConnectionReset)
                {
                    continue;
                }
                if (got < 3 || buf[0] != 0x05)
                    throw new IOException("unexpected SQL Browser reply from " + host);
                int size = buf[1] | (buf[2] << 8);
                int n = Math.Min(size, got - 3);
                reply = Encoding.Latin1.GetString(buf, 3, n);
            }
        }
        if (reply == null)
            throw new IOException("no answer from SQL Browser at " + host + ":" + udpPort
                + " for instance " + instance
                + " (unknown instance, UDP blocked or SQL Server Browser service not running?)");
        return ParsePort(reply, instance, host);
    }

    static int ParsePort(string reply, string instance, string host)
    {
        // the reply may list several instances, each terminated by ";;"
        foreach (string entry in reply.Split(";;"))
        {
            string[] f = entry.Split(';');
            string? inst = null, tcp = null;
            for (int i = 0; i + 1 < f.Length; i += 2)
            {
                if (f[i].Equals("InstanceName", StringComparison.OrdinalIgnoreCase)) inst = f[i + 1];
                else if (f[i].Equals("tcp", StringComparison.OrdinalIgnoreCase)) tcp = f[i + 1];
            }
            if (inst != null && inst.Equals(instance, StringComparison.OrdinalIgnoreCase))
            {
                if (string.IsNullOrEmpty(tcp))
                    throw new IOException("instance " + instance + " on " + host
                        + " has no TCP endpoint (TCP/IP disabled?)");
                return int.Parse(tcp.Trim());
            }
        }
        throw new IOException("SQL Browser at " + host + " does not know instance " + instance);
    }
}
