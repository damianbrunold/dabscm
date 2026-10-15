using System;
using System.IO;
using System.Net.Sockets;
using System.Net.Security;
using System.Security.Authentication;

namespace scheme;

public class PrimitiveTdsConnect : Primitive
{
    public override string Name() => "tds-connect";

    public override string Info() =>
        "Syntax: (tds-connect host port)\n" +
        "Syntax: (tds-connect host port encrypt? verify? cert-host)\n" +
        "Library: (scm core)\n" +
        "Description: Connects to a SQL Server at the given host and port using TDS.\n" +
        "  Performs the PreLogin exchange and, when encrypt? is true (default), the TLS\n" +
        "  handshake (wrapped in TDS PRELOGIN packets); the whole session is then encrypted.\n" +
        "  With verify? true the certificate chain and host name (cert-host, default host)\n" +
        "  are validated, otherwise any certificate is accepted (default). With encrypt? #f\n" +
        "  no TLS is used, which fails if the server requires encryption.\n" +
        "  SCM_TDS_DEBUG=1 prints the negotiation to stderr.\n" +
        "  Returns a socket suitable for use with the (scm database sqlserver) library.\n" +
        "Example:\n" +
        "  (define sock (tds-connect \"localhost\" 1433))";

    const int EncryptOff = 0, EncryptOn = 1, EncryptNotSup = 2, EncryptReq = 3;

    private static bool Debug()
    {
        string? v = Environment.GetEnvironmentVariable("SCM_TDS_DEBUG");
        if (v == null) return false;
        v = v.Trim().ToLowerInvariant();
        return v == "1" || v == "true" || v == "yes";
    }

    private static void Log(string msg)
    {
        if (Debug()) Console.Error.WriteLine("scm-tds: " + msg);
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 5);
        string host = new String(Value.AsString(arguments[0]));
        int port = IntegerMath.ToInt(arguments[1]);
        bool encrypt = !(arguments.Length > 2 && arguments[2] is bool b2 && !b2);
        bool verify = arguments.Length > 3 && !(arguments[3] is bool b3 && !b3);
        string certHost = arguments.Length > 4 && !(arguments[4] is bool b4 && !b4)
            ? new String(Value.AsString(arguments[4])) : host;
        if (verify && TlsTrust.InsecureRequested())
        {
            Console.Error.WriteLine(
                "warning: SCM_TLS_INSECURE is set, SQL Server certificate verification is disabled");
            verify = false;
        }
        string step = "connect";
        try
        {
            var client = new TcpClient();
            client.NoDelay = true;
            client.Connect(host, port);
            var netStream = client.GetStream();
            Log("tcp connected to " + host + ":" + port);

            step = "prelogin";
            SendPreLogin(netStream, encrypt ? EncryptOn : EncryptNotSup);
            int serverEnc = ReadPreLoginResponse(netStream);
            Log("server encryption flag " + serverEnc);
            if (encrypt && serverEnc == EncryptNotSup)
                throw new IOException("server does not support encryption (use encrypt #f)");
            if (!encrypt && (serverEnc == EncryptReq || serverEnc == EncryptOn))
                throw new IOException("server requires encryption");
            if (!encrypt)
                return new NativeValue(new SchemeSocket(client));

            step = "tls";
            var tlsStream = new TdsTlsStream(netStream);
            var ssl = new SslStream(tlsStream, false,
                (s, cert, chain, errors) => !verify || errors == SslPolicyErrors.None);
            ssl.AuthenticateAsClient(new SslClientAuthenticationOptions
            {
                TargetHost = certHost,
                EnabledSslProtocols = System.Security.Authentication.SslProtocols.Tls12
            });
            tlsStream.SetHandshakeComplete();
            Log("tls " + ssl.SslProtocol + " " + ssl.NegotiatedCipherSuite
                + (ssl.RemoteCertificate != null ? ", server certificate " + ssl.RemoteCertificate.Subject : ""));

            return new NativeValue(new SchemeSocket(client, ssl));
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "tds-connect (" + step + "): " + e.Message);
        }
    }

    // Send a TDS PreLogin packet (type 0x12) with the given ENCRYPTION option
    private static void SendPreLogin(Stream stream, int encryption)
    {
        // Body: VERSION option (offset=11, len=6) + ENCRYPTION option (offset=17, len=1) + terminator
        byte[] body = new byte[]
        {
            0x00, 0x00, 0x0B, 0x00, 0x06,              // VERSION: offset=11, length=6
            0x01, 0x00, 0x11, 0x00, 0x01,              // ENCRYPTION: offset=17, length=1
            0xFF,                                       // terminator
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,        // VERSION value (all zeros)
            (byte)encryption
        };
        WriteTdsPacket(stream, 0x12, body);
    }

    // Read the server's PreLogin response (all packets up to EOM); returns its ENCRYPTION value
    private static int ReadPreLoginResponse(Stream stream)
    {
        var acc = new MemoryStream();
        while (true)
        {
            byte[] header = new byte[8];
            ReadExact(stream, header, 0, 8);
            int length = (header[2] << 8) | header[3];
            byte[] part = new byte[length - 8];
            ReadExact(stream, part, 0, part.Length);
            acc.Write(part, 0, part.Length);
            if ((header[1] & 0x01) != 0) break;
        }
        byte[] body = acc.ToArray();
        int enc = EncryptNotSup;
        for (int i = 0; i + 4 < body.Length && body[i] != 0xFF; i += 5)
        {
            int token = body[i];
            int off = (body[i + 1] << 8) | body[i + 2];
            int len = (body[i + 3] << 8) | body[i + 4];
            if (token == 0x00 && len >= 4 && off + 4 <= body.Length)
                Log("server version " + body[off] + "." + body[off + 1] + "." + ((body[off + 2] << 8) | body[off + 3]));
            if (token == 0x01 && len >= 1 && off < body.Length) enc = body[off];
        }
        return enc;
    }

    // Write a TDS message: payload split into packets of at most 4096 bytes, EOM on the last
    private static void WriteTdsPacket(Stream stream, byte type, byte[] payload)
        => WriteTdsPacket(stream, type, payload, 0, payload.Length);

    internal static void WriteTdsPacket(Stream stream, byte type, byte[] payload, int offset, int count)
    {
        const int max = 4096 - 8;
        int pos = 0, id = 1;
        do
        {
            int n = Math.Min(max, count - pos);
            bool last = pos + n >= count;
            byte[] header = new byte[8];
            header[0] = type;
            header[1] = (byte)(last ? 0x01 : 0x00);   // EOM status
            header[2] = (byte)((n + 8) >> 8);
            header[3] = (byte)((n + 8) & 0xFF);
            header[6] = (byte)id++;                   // packet ID
            stream.Write(header, 0, 8);
            stream.Write(payload, offset + pos, n);
            pos += n;
        } while (pos < count);
        stream.Flush();
    }

    private static void ReadExact(Stream stream, byte[] buffer, int offset, int count)
    {
        int read = 0;
        while (read < count)
        {
            int n = stream.Read(buffer, offset + read, count - read);
            if (n <= 0) throw new IOException("Connection closed during TDS read");
            read += n;
        }
    }

    // Wraps a Stream to inject/strip TDS PRELOGIN (0x12) packet framing during the TLS handshake.
    // After SetHandshakeComplete(), all I/O passes through to the inner stream unchanged.
    private sealed class TdsTlsStream : Stream
    {
        private readonly Stream _inner;
        private bool _handshakeComplete;
        private byte[] _readBuf = Array.Empty<byte>();
        private int _readPos;

        public TdsTlsStream(Stream inner) { _inner = inner; }

        public void SetHandshakeComplete() => _handshakeComplete = true;

        public override bool CanRead  => true;
        public override bool CanWrite => true;
        public override bool CanSeek  => false;
        public override long Length   => throw new NotSupportedException();
        public override long Position
        {
            get => throw new NotSupportedException();
            set => throw new NotSupportedException();
        }

        public override void Write(byte[] buffer, int offset, int count)
        {
            if (_handshakeComplete)
            {
                _inner.Write(buffer, offset, count);
                return;
            }
            // Wrap TLS bytes in TDS PRELOGIN (0x12) packets
            WriteTdsPacket(_inner, 0x12, buffer, offset, count);
        }

        public override int Read(byte[] buffer, int offset, int count)
        {
            if (_handshakeComplete)
                return _inner.Read(buffer, offset, count);

            // Return any buffered data from a previous packet read
            if (_readPos < _readBuf.Length)
            {
                int avail = _readBuf.Length - _readPos;
                int n = Math.Min(count, avail);
                Array.Copy(_readBuf, _readPos, buffer, offset, n);
                _readPos += n;
                return n;
            }

            // Read the next TDS packet header and body
            byte[] hdr = new byte[8];
            ReadExactFrom(_inner, hdr, 0, 8);
            int total = (hdr[2] << 8) | hdr[3];
            int bodyLen = total - 8;
            _readBuf = new byte[bodyLen];
            ReadExactFrom(_inner, _readBuf, 0, bodyLen);
            _readPos = 0;

            int take = Math.Min(count, bodyLen);
            Array.Copy(_readBuf, 0, buffer, offset, take);
            _readPos = take;
            return take;
        }

        private static void ReadExactFrom(Stream s, byte[] buf, int off, int len)
        {
            int read = 0;
            while (read < len)
            {
                int n = s.Read(buf, off + read, len - read);
                if (n <= 0) throw new IOException("Connection closed during TDS/TLS handshake read");
                read += n;
            }
        }

        public override void Flush() => _inner.Flush();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
    }
}
