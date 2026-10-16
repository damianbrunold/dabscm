package scheme.primitives;
import scheme.*;
import java.net.*;
import java.nio.charset.StandardCharsets;

public class PrimitiveSqlBrowserPort extends Primitive {
    @Override
    public String name() { return "sql-browser-port"; }

    @Override
    public String info() {
        return "Syntax: (sql-browser-port host instance)\n" +
               "Syntax: (sql-browser-port host instance timeout-ms)\n" +
               "Library: (scm core)\n" +
               "Description: Asks the SQL Server Browser service on host (UDP 1434) for the TCP\n" +
               "  port of the named instance and returns it as an integer. Raises an error when\n" +
               "  the browser does not answer within timeout-ms (default 5000, two attempts) or\n" +
               "  the instance has no TCP endpoint. SCM_SQL_BROWSER_PORT overrides the UDP port\n" +
               "  (for tests).\n" +
               "Example:\n" +
               "  (sql-browser-port \"dbhost\" \"SQLEXPRESS\") ; => 49170";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        String host = new String(Value.asString(arguments[0]));
        String instance = new String(Value.asString(arguments[1]));
        int timeout = arguments.length > 2 ? IntegerMath.toInt(arguments[2]) : 5000;
        try {
            return (long) lookup(host, instance, timeout);
        } catch (Exception e) {
            throw new SchemeError(pos, "sql-browser-port: " + e.getMessage());
        }
    }

    static int browserPort() {
        String v = System.getenv("SCM_SQL_BROWSER_PORT");
        if (v != null && !v.isBlank()) return Integer.parseInt(v.trim());
        return 1434;
    }

    // SSRP CLNT_UCAST_INST request; the reply is SVR_RESP 0x05, u16 LE size, then
    // "ServerName;S;InstanceName;I;IsClustered;No;Version;V;tcp;PORT;np;...;;"
    public static int lookup(String host, String instance, int timeoutMs) throws Exception {
        int udpPort = browserPort();
        byte[] name = instance.getBytes(StandardCharsets.US_ASCII);
        byte[] req = new byte[name.length + 1];
        req[0] = 0x04;
        System.arraycopy(name, 0, req, 1, name.length);
        InetAddress addr = InetAddress.getByName(host);
        String reply = null;
        try (DatagramSocket sock = new DatagramSocket()) {
            sock.setSoTimeout(Math.max(1, timeoutMs / 2));
            for (int attempt = 0; attempt < 2 && reply == null; attempt++) {
                sock.send(new DatagramPacket(req, req.length, addr, udpPort));
                byte[] buf = new byte[65535];
                DatagramPacket resp = new DatagramPacket(buf, buf.length);
                try {
                    sock.receive(resp);
                } catch (SocketTimeoutException e) {
                    continue;
                }
                if (resp.getLength() < 3 || (buf[0] & 0xFF) != 0x05)
                    throw new java.io.IOException("unexpected SQL Browser reply from " + host);
                int size = (buf[1] & 0xFF) | ((buf[2] & 0xFF) << 8);
                int n = Math.min(size, resp.getLength() - 3);
                reply = new String(buf, 3, n, StandardCharsets.ISO_8859_1);
            }
        }
        if (reply == null)
            throw new java.io.IOException("no answer from SQL Browser at " + host + ":" + udpPort
                + " for instance " + instance
                + " (unknown instance, UDP blocked or SQL Server Browser service not running?)");
        return parsePort(reply, instance, host);
    }

    static int parsePort(String reply, String instance, String host) throws java.io.IOException {
        // the reply may list several instances, each terminated by ";;"
        for (String entry : reply.split(";;")) {
            String[] f = entry.split(";", -1);
            String inst = null, tcp = null;
            for (int i = 0; i + 1 < f.length; i += 2) {
                if (f[i].equalsIgnoreCase("InstanceName")) inst = f[i + 1];
                else if (f[i].equalsIgnoreCase("tcp")) tcp = f[i + 1];
            }
            if (inst != null && inst.equalsIgnoreCase(instance)) {
                if (tcp == null || tcp.isEmpty())
                    throw new java.io.IOException("instance " + instance + " on " + host
                        + " has no TCP endpoint (TCP/IP disabled?)");
                return Integer.parseInt(tcp.trim());
            }
        }
        throw new java.io.IOException("SQL Browser at " + host + " does not know instance " + instance);
    }
}
