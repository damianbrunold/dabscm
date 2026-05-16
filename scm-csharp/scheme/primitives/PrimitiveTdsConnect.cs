using System;
using System.IO;
using System.Net.Sockets;
using System.Net.Security;

namespace scheme;

public class PrimitiveTdsConnect : Primitive
{
    public override string Name() => "tds-connect";

    public override string Info() =>
        "Syntax: (tds-connect host port)\n" +
        "Library: (scm database sqlserver)\n" +
        "Description: Connects to a SQL Server at the given host and port using TDS with TLS.\n" +
        "  Performs the PreLogin exchange and TLS handshake (wrapped in TDS type 0x17 packets)\n" +
        "  then returns a socket suitable for use with the (scm database sqlserver) library.\n" +
        "Example:\n" +
        "  (define sock (tds-connect \"localhost\" 1433))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        string host = new String(Value.AsString(arguments[0]));
        int port = IntegerMath.ToInt(arguments[1]);
        try
        {
            var client = new TcpClient(host, port);
            var netStream = client.GetStream();

            // Send PreLogin with ENCRYPT_ON, read response
            SendPreLogin(netStream);
            ReadPreLoginResponse(netStream);

            // TLS handshake wrapped in TDS type 0x17 packets
            var tlsStream = new TdsTlsStream(netStream);
            var ssl = new SslStream(tlsStream, false, (s, c, ch, e) => true);
            ssl.AuthenticateAsClient(host);
            tlsStream.SetHandshakeComplete();

            return new NativeValue(new SchemeSocket(client, ssl));
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "tds-connect: " + e.Message);
        }
    }

    // Send a TDS PreLogin packet (type 0x12) with ENCRYPT_ON
    private static void SendPreLogin(Stream stream)
    {
        // Body: VERSION option (offset=11, len=6) + ENCRYPTION option (offset=17, len=1) + terminator
        byte[] body = new byte[]
        {
            0x00, 0x00, 0x0B, 0x00, 0x06,              // VERSION: offset=11, length=6
            0x01, 0x00, 0x11, 0x00, 0x01,              // ENCRYPTION: offset=17, length=1
            0xFF,                                       // terminator
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,        // VERSION value (all zeros)
            0x01                                        // ENCRYPTION = ENCRYPT_ON
        };
        WriteTdsPacket(stream, 0x12, body);
    }

    // Read and discard the server's PreLogin response
    private static void ReadPreLoginResponse(Stream stream)
    {
        byte[] header = new byte[8];
        ReadExact(stream, header, 0, 8);
        int length = (header[2] << 8) | header[3];
        byte[] body = new byte[length - 8];
        ReadExact(stream, body, 0, body.Length);
    }

    // Write a TDS packet: header(8) + payload
    private static void WriteTdsPacket(Stream stream, byte type, byte[] payload)
    {
        int total = 8 + payload.Length;
        byte[] header = new byte[8];
        header[0] = type;
        header[1] = 0x01;               // EOM status (last packet)
        header[2] = (byte)(total >> 8);
        header[3] = (byte)(total & 0xFF);
        header[4] = 0x00;               // SPID high
        header[5] = 0x00;               // SPID low
        header[6] = 0x01;               // packet ID
        header[7] = 0x00;               // window
        stream.Write(header, 0, 8);
        stream.Write(payload, 0, payload.Length);
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

    // Wraps a Stream to inject/strip TDS type-0x17 packet framing during TLS handshake.
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
            // Wrap TLS bytes in a TDS type 0x17 packet
            int total = 8 + count;
            byte[] hdr = new byte[8];
            hdr[0] = 0x17;
            hdr[1] = 0x01;               // EOM
            hdr[2] = (byte)(total >> 8);
            hdr[3] = (byte)(total & 0xFF);
            hdr[4] = 0x00; hdr[5] = 0x00;
            hdr[6] = 0x01; hdr[7] = 0x00;
            _inner.Write(hdr, 0, 8);
            _inner.Write(buffer, offset, count);
            _inner.Flush();
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
