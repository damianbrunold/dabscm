package scheme.primitives;
import scheme.*;
import java.io.*;
import java.net.*;
import java.nio.ByteBuffer;
import javax.net.ssl.*;

public class PrimitiveTdsConnect extends Primitive {
    @Override
    public String name() { return "tds-connect"; }

    @Override
    public String info() {
        return "Syntax: (tds-connect host port)\n" +
               "Library: (scm core)\n" +
               "Description: Connects to a SQL Server at the given host and port using TDS with TLS.\n" +
               "  Performs the PreLogin exchange and TLS handshake (wrapped in TDS type 0x17 packets)\n" +
               "  then returns a socket suitable for use with the (scm database sqlserver) library.\n" +
               "Example:\n" +
               "  (define sock (tds-connect \"localhost\" 1433))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        String host = new String(Value.asString(arguments[0]));
        int port = IntegerMath.toInt(arguments[1]);
        try {
            Socket socket = new Socket(host, port);
            InputStream rawIn = socket.getInputStream();
            OutputStream rawOut = socket.getOutputStream();

            // Send PreLogin with ENCRYPT_ON, read response
            sendPreLogin(rawOut);
            readPreLoginResponse(rawIn);

            // Set up SSLEngine (trust all certificates)
            SSLContext ctx = SSLContext.getInstance("TLS");
            ctx.init(null, new TrustManager[]{ new TrustAllX509() }, null);
            SSLEngine engine = ctx.createSSLEngine(host, port);
            engine.setUseClientMode(true);

            // TLS handshake wrapped in TDS type 0x17 packets
            doTlsHandshake(engine, rawIn, rawOut);

            // Post-handshake: create SSL-wrapped streams for all further I/O
            SslEngineInputStream  sslIn  = new SslEngineInputStream(rawIn, engine);
            SslEngineOutputStream sslOut = new SslEngineOutputStream(rawOut, engine);

            return new NativeValue(new SchemeSocket(socket, sslIn, sslOut));
        } catch (Exception e) {
            throw new SchemeError(pos, "tds-connect: " + e.getMessage());
        }
    }

    // -------------------------------------------------------------------------
    // PreLogin helpers
    // -------------------------------------------------------------------------

    private static void sendPreLogin(OutputStream out) throws IOException {
        byte[] body = {
            0x00, 0x00, 0x0B, 0x00, 0x06,              // VERSION: offset=11, length=6
            0x01, 0x00, 0x11, 0x00, 0x01,              // ENCRYPTION: offset=17, length=1
            (byte)0xFF,                                 // terminator
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,        // VERSION value
            0x01                                        // ENCRYPTION = ENCRYPT_ON
        };
        writeTdsPacket(out, (byte)0x12, body);
    }

    private static void readPreLoginResponse(InputStream in) throws IOException {
        byte[] hdr = readExact(in, 8);
        int len = ((hdr[2] & 0xFF) << 8) | (hdr[3] & 0xFF);
        readExact(in, len - 8); // discard body
    }

    private static void writeTdsPacket(OutputStream out, byte type, byte[] payload) throws IOException {
        int total = 8 + payload.length;
        byte[] hdr = new byte[8];
        hdr[0] = type;
        hdr[1] = 0x01;               // EOM
        hdr[2] = (byte)(total >> 8);
        hdr[3] = (byte)(total & 0xFF);
        hdr[4] = 0x00; hdr[5] = 0x00;
        hdr[6] = 0x01; hdr[7] = 0x00;
        out.write(hdr);
        out.write(payload);
        out.flush();
    }

    private static byte[] readTdsPacketBody(InputStream in) throws IOException {
        byte[] hdr = readExact(in, 8);
        int len = ((hdr[2] & 0xFF) << 8) | (hdr[3] & 0xFF);
        return readExact(in, len - 8);
    }

    private static byte[] readExact(InputStream in, int n) throws IOException {
        byte[] buf = new byte[n];
        int got = 0;
        while (got < n) {
            int r = in.read(buf, got, n - got);
            if (r < 0) throw new EOFException("TDS stream closed");
            got += r;
        }
        return buf;
    }

    // -------------------------------------------------------------------------
    // TLS handshake (wrapped in TDS 0x17 packets)
    // -------------------------------------------------------------------------

    private static void doTlsHandshake(SSLEngine engine, InputStream rawIn, OutputStream rawOut)
            throws Exception {
        engine.beginHandshake();
        int appBufSize = engine.getSession().getApplicationBufferSize();
        int netBufSize = engine.getSession().getPacketBufferSize();
        ByteBuffer appIn  = ByteBuffer.allocate(appBufSize + 50);
        ByteBuffer netOut = ByteBuffer.allocate(netBufSize + 50);
        ByteBuffer empty  = ByteBuffer.allocate(0);

        SSLEngineResult.HandshakeStatus hs = engine.getHandshakeStatus();
        while (hs != SSLEngineResult.HandshakeStatus.FINISHED &&
               hs != SSLEngineResult.HandshakeStatus.NOT_HANDSHAKING) {
            switch (hs) {
                case NEED_WRAP: {
                    netOut.clear();
                    SSLEngineResult res = engine.wrap(empty, netOut);
                    netOut.flip();
                    if (netOut.hasRemaining()) {
                        byte[] data = new byte[netOut.remaining()];
                        netOut.get(data);
                        writeTdsPacket(rawOut, (byte)0x17, data);
                    }
                    hs = res.getHandshakeStatus();
                    break;
                }
                case NEED_UNWRAP: {
                    byte[] body = readTdsPacketBody(rawIn);
                    ByteBuffer netIn = ByteBuffer.wrap(body);
                    appIn.clear();
                    SSLEngineResult res;
                    do {
                        res = engine.unwrap(netIn, appIn);
                    } while (res.getStatus() == SSLEngineResult.Status.OK &&
                             res.getHandshakeStatus() == SSLEngineResult.HandshakeStatus.NEED_UNWRAP &&
                             netIn.hasRemaining());
                    hs = res.getHandshakeStatus();
                    break;
                }
                case NEED_TASK: {
                    Runnable task;
                    while ((task = engine.getDelegatedTask()) != null) task.run();
                    hs = engine.getHandshakeStatus();
                    break;
                }
                default:
                    hs = engine.getHandshakeStatus();
            }
        }
    }

    // -------------------------------------------------------------------------
    // Trust-all certificate verifier
    // -------------------------------------------------------------------------

    private static class TrustAllX509 implements javax.net.ssl.X509TrustManager {
        public void checkClientTrusted(java.security.cert.X509Certificate[] c, String a) {}
        public void checkServerTrusted(java.security.cert.X509Certificate[] c, String a) {}
        public java.security.cert.X509Certificate[] getAcceptedIssuers() {
            return new java.security.cert.X509Certificate[0];
        }
    }

    // -------------------------------------------------------------------------
    // Post-handshake SSL-wrapped InputStream
    // -------------------------------------------------------------------------

    static class SslEngineInputStream extends InputStream {
        private final InputStream rawIn;
        private final SSLEngine engine;
        private ByteBuffer appBuf;
        private final byte[] oneByte = new byte[1];

        SslEngineInputStream(InputStream rawIn, SSLEngine engine) {
            this.rawIn  = rawIn;
            this.engine = engine;
            this.appBuf = ByteBuffer.allocate(engine.getSession().getApplicationBufferSize() + 50);
            this.appBuf.limit(0); // mark empty
        }

        @Override
        public int read() throws IOException {
            int n = read(oneByte, 0, 1);
            return n < 0 ? -1 : (oneByte[0] & 0xFF);
        }

        @Override
        public int read(byte[] buf, int off, int len) throws IOException {
            while (true) {
                if (appBuf.hasRemaining()) {
                    int n = Math.min(len, appBuf.remaining());
                    appBuf.get(buf, off, n);
                    return n;
                }
                // Read one TLS record from the raw socket
                byte[] tlsRec = readTlsRecord(rawIn);
                ByteBuffer netBuf = ByteBuffer.wrap(tlsRec);
                appBuf.clear();
                SSLEngineResult res = engine.unwrap(netBuf, appBuf);
                appBuf.flip();
                if (res.getStatus() == SSLEngineResult.Status.CLOSED) return -1;
            }
        }

        // Read one TLS record (5-byte header + body)
        private static byte[] readTlsRecord(InputStream in) throws IOException {
            byte[] hdr = new byte[5];
            int got = 0;
            while (got < 5) {
                int n = in.read(hdr, got, 5 - got);
                if (n < 0) throw new EOFException("TLS stream closed");
                got += n;
            }
            int recLen = ((hdr[3] & 0xFF) << 8) | (hdr[4] & 0xFF);
            byte[] body = new byte[recLen];
            got = 0;
            while (got < recLen) {
                int n = in.read(body, got, recLen - got);
                if (n < 0) throw new EOFException("TLS stream closed");
                got += n;
            }
            byte[] full = new byte[5 + recLen];
            System.arraycopy(hdr, 0, full, 0, 5);
            System.arraycopy(body, 0, full, 5, recLen);
            return full;
        }
    }

    // -------------------------------------------------------------------------
    // Post-handshake SSL-wrapped OutputStream
    // -------------------------------------------------------------------------

    static class SslEngineOutputStream extends OutputStream {
        private final OutputStream rawOut;
        private final SSLEngine engine;
        private final ByteBuffer netBuf;

        SslEngineOutputStream(OutputStream rawOut, SSLEngine engine) {
            this.rawOut = rawOut;
            this.engine = engine;
            this.netBuf = ByteBuffer.allocate(engine.getSession().getPacketBufferSize() + 50);
        }

        @Override
        public void write(int b) throws IOException {
            write(new byte[]{(byte)b}, 0, 1);
        }

        @Override
        public void write(byte[] buf, int off, int len) throws IOException {
            ByteBuffer appBuf = ByteBuffer.wrap(buf, off, len);
            while (appBuf.hasRemaining()) {
                netBuf.clear();
                engine.wrap(appBuf, netBuf);
                netBuf.flip();
                if (netBuf.hasRemaining()) {
                    byte[] data = new byte[netBuf.remaining()];
                    netBuf.get(data);
                    rawOut.write(data);
                }
            }
        }

        @Override
        public void flush() throws IOException { rawOut.flush(); }
    }
}
