using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;

namespace scheme;

// A WebSocket connection (RFC 6455) after the handshake: from ws-accept,
// ws-connect or an HTTP upgrade (http-websocket-upgrade). One thread
// receives; any thread may send (sends are serialized). Pings are answered
// with pongs, fragmented messages are joined, a close frame is answered and
// ends the connection. The same logic is in scm-java/.../SchemeWebSocket.java.
public class SchemeWebSocket
{
    public const long DefaultMaxMessageBytes = 16L * 1024 * 1024;
    // What Receive returns when no frame arrived within the timeout.
    public static readonly string Timeout = Value.Intern("timeout");

    public readonly Stream stream;
    public readonly bool IsServer;
    public readonly TcpClient? Client;   // closed by Shutdown; may be null
    public long MaxMessageBytes = DefaultMaxMessageBytes;
    private readonly object writeLock = new object();
    private volatile bool closeSent;
    private volatile bool closed;

    public SchemeWebSocket(Stream stream, bool isServer, TcpClient? client = null)
    {
        this.stream = stream;
        this.IsServer = isServer;
        this.Client = client;
    }

    public bool IsClosed => closed;

    // The Sec-WebSocket-Accept value for a Sec-WebSocket-Key.
    public static string AcceptKey(string key) =>
        Convert.ToBase64String(SHA1.HashData(Encoding.UTF8.GetBytes(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")));

    // Reads HTTP headers byte by byte up to the empty line (so that no frame
    // bytes behind them are consumed) and returns them, or null at EOF.
    public static string? ReadHeaders(Stream input)
    {
        var buf = new MemoryStream(512);
        int matched = 0;
        while (matched < 4)
        {
            int b = input.ReadByte();
            if (b < 0) return null;
            buf.WriteByte((byte)b);
            if ((matched == 0 || matched == 2) && b == '\r') matched++;
            else if ((matched == 1 || matched == 3) && b == '\n') matched++;
            else matched = b == '\r' ? 1 : 0;
            if (buf.Length > 64 * 1024) throw new IOException("headers too long");
        }
        return Encoding.Latin1.GetString(buf.ToArray());
    }

    // --- sending ---

    public void Send(int opcode, byte[] payload)
    {
        lock (writeLock)
        {
            if (closeSent) throw new IOException("the connection is closed");
            WriteFrame(opcode, payload);
        }
    }

    private void WriteFrame(int opcode, byte[] payload)
    {
        int len = payload.Length;
        bool mask = !IsServer;              // clients mask, servers don't
        var f = new MemoryStream(len + 14);
        f.WriteByte((byte)(0x80 | opcode));
        int maskBit = mask ? 0x80 : 0x00;
        if (len < 126)
        {
            f.WriteByte((byte)(maskBit | len));
        }
        else if (len < 65536)
        {
            f.WriteByte((byte)(maskBit | 126));
            f.WriteByte((byte)(len >> 8));
            f.WriteByte((byte)(len & 0xFF));
        }
        else
        {
            f.WriteByte((byte)(maskBit | 127));
            for (int i = 7; i >= 0; i--) f.WriteByte((byte)(((long)len >> (i * 8)) & 0xFF));
        }
        if (mask)
        {
            byte[] key = RandomNumberGenerator.GetBytes(4);
            f.Write(key, 0, 4);
            for (int i = 0; i < len; i++) f.WriteByte((byte)(payload[i] ^ key[i % 4]));
        }
        else
        {
            f.Write(payload, 0, len);
        }
        var bytes = f.ToArray();
        stream.Write(bytes, 0, bytes.Length);
        stream.Flush();
    }

    // Sends a close frame (once) with a status code; the peer's answer ends Receive.
    public void Close(int code)
    {
        lock (writeLock)
        {
            if (closeSent) return;
            closeSent = true;
            try { WriteFrame(0x8, new byte[] { (byte)(code >> 8), (byte)code }); }
            catch (Exception) { }
        }
    }

    // Closes the connection without the close handshake.
    public void Shutdown()
    {
        closed = true;
        closeSent = true;
        try
        {
            if (Client != null) Client.Close();
            else stream.Close();
        }
        catch (Exception) { }
    }

    // --- receiving ---

    private int ReadByte()
    {
        int b = stream.ReadByte();
        if (b < 0) throw new EndOfStreamException();
        return b;
    }

    private void ReadFully(byte[] buf, int off, int len)
    {
        while (len > 0)
        {
            int r = stream.Read(buf, off, len);
            if (r <= 0) throw new EndOfStreamException();
            off += r;
            len -= r;
        }
    }

    // The next message: a char[] (text), a byte[] (binary), #f when the
    // connection has closed, or Timeout when timeoutMs > 0 and no frame
    // began within it.
    public object Receive(int timeoutMs)
    {
        if (closed) return Value.F;
        MemoryStream? message = null;
        int messageOpcode = 0;
        try
        {
            while (true)
            {
                int b0;
                if (timeoutMs > 0 && message == null && stream.CanTimeout)
                {
                    stream.ReadTimeout = timeoutMs;
                    try
                    {
                        b0 = ReadByte();
                    }
                    catch (IOException e) when (e.InnerException is SocketException se
                                                && se.SocketErrorCode == SocketError.TimedOut)
                    {
                        return Timeout;
                    }
                    finally
                    {
                        stream.ReadTimeout = System.Threading.Timeout.Infinite;
                    }
                }
                else
                {
                    b0 = ReadByte();
                }
                int b1 = ReadByte();
                bool fin = (b0 & 0x80) != 0;
                int opcode = b0 & 0x0F;
                bool masked = (b1 & 0x80) != 0;
                long len = b1 & 0x7F;
                if (len == 126)
                {
                    len = (ReadByte() << 8) | ReadByte();
                }
                else if (len == 127)
                {
                    len = 0;
                    for (int i = 0; i < 8; i++) len = (len << 8) | (long)ReadByte();
                }
                if (IsServer && !masked) return Fail(1002);     // clients must mask
                bool control = opcode >= 0x8;
                if (control && (len > 125 || !fin)) return Fail(1002);
                long total = (message == null ? 0 : message.Length) + len;
                if (len < 0 || total > MaxMessageBytes) return Fail(1009);
                byte[] key = new byte[4];
                if (masked) ReadFully(key, 0, 4);
                byte[] payload = new byte[len];
                ReadFully(payload, 0, (int)len);
                if (masked) for (int i = 0; i < payload.Length; i++) payload[i] ^= key[i % 4];
                switch (opcode)
                {
                    case 0x9:                                       // ping
                        lock (writeLock) { if (!closeSent) WriteFrame(0xA, payload); }
                        continue;
                    case 0xA:                                       // pong
                        continue;
                    case 0x8:                                       // close
                    {
                        int code = payload.Length >= 2 ? (payload[0] << 8) | payload[1] : 1000;
                        Close(code == 1005 || code == 1006 ? 1000 : code);
                        Shutdown();
                        return Value.F;
                    }
                    case 0x0:                                       // continuation
                        if (message == null) return Fail(1002);
                        message.Write(payload, 0, payload.Length);
                        break;
                    case 0x1:
                    case 0x2:
                        if (message != null) return Fail(1002);
                        messageOpcode = opcode;
                        message = new MemoryStream(payload.Length);
                        message.Write(payload, 0, payload.Length);
                        break;
                    default:
                        return Fail(1002);
                }
                if (fin)
                {
                    byte[] data = message.ToArray();
                    return messageOpcode == 0x1 ? Encoding.UTF8.GetString(data).ToCharArray() : data;
                }
            }
        }
        catch (Exception e) when (e is IOException || e is ObjectDisposedException || e is SocketException)
        {
            Shutdown();
            return Value.F;
        }
    }

    private object Fail(int code)
    {
        Close(code);
        Shutdown();
        return Value.F;
    }

    public override string ToString() => "#<websocket>";
}
