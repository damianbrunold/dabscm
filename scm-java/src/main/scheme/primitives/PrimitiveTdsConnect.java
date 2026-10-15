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
               "Syntax: (tds-connect host port encrypt? verify? cert-host)\n" +
               "Library: (scm core)\n" +
               "Description: Connects to a SQL Server at the given host and port using TDS.\n" +
               "  Performs the PreLogin exchange and, when encrypt? is true (default), the TLS\n" +
               "  handshake (wrapped in TDS PRELOGIN packets); the whole session is then encrypted.\n" +
               "  With verify? true the certificate chain and host name (cert-host, default host)\n" +
               "  are validated, otherwise any certificate is accepted (default). With encrypt? #f\n" +
               "  no TLS is used, which fails if the server requires encryption.\n" +
               "  SCM_TDS_DEBUG=1 prints the negotiation to stderr; SCM_TDS_TLS_PROTOCOLS\n" +
               "  overrides the enabled TLS versions (default TLSv1.2).\n" +
               "  Returns a socket suitable for use with the (scm database sqlserver) library.\n" +
               "Example:\n" +
               "  (define sock (tds-connect \"localhost\" 1433))";
    }

    static final int ENCRYPT_OFF = 0, ENCRYPT_ON = 1, ENCRYPT_NOT_SUP = 2, ENCRYPT_REQ = 3;

    private static boolean debug() {
        String v = System.getenv("SCM_TDS_DEBUG");
        return v != null && (v.equals("1") || v.equalsIgnoreCase("true") || v.equalsIgnoreCase("yes"));
    }

    private static void log(String msg) {
        if (debug()) System.err.println("scm-tds: " + msg);
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 5);
        String host = new String(Value.asString(arguments[0]));
        int port = IntegerMath.toInt(arguments[1]);
        boolean encrypt = !(arguments.length > 2 && Boolean.FALSE.equals(arguments[2]));
        boolean verify = arguments.length > 3 && !Boolean.FALSE.equals(arguments[3]);
        String certHost = arguments.length > 4 && !Boolean.FALSE.equals(arguments[4])
            ? new String(Value.asString(arguments[4])) : host;
        if (verify && TlsTrust.insecureRequested()) {
            System.err.println("warning: SCM_TLS_INSECURE is set, "
                + "SQL Server certificate verification is disabled");
            verify = false;
        }
        String step = "connect";
        try {
            Socket socket = new Socket();
            socket.connect(new InetSocketAddress(host, port), 30000);
            socket.setTcpNoDelay(true);
            InputStream rawIn = socket.getInputStream();
            OutputStream rawOut = socket.getOutputStream();
            log("tcp connected to " + host + ":" + port);

            step = "prelogin";
            sendPreLogin(rawOut, encrypt ? ENCRYPT_ON : ENCRYPT_NOT_SUP);
            int serverEnc = readPreLoginResponse(rawIn);
            log("server encryption flag " + serverEnc);
            if (encrypt && serverEnc == ENCRYPT_NOT_SUP)
                throw new IOException("server does not support encryption (use encrypt #f)");
            if (!encrypt && serverEnc == ENCRYPT_REQ)
                throw new IOException("server requires encryption");
            if (!encrypt && serverEnc == ENCRYPT_ON)
                throw new IOException("server requires encryption");
            if (!encrypt)
                return new NativeValue(new SchemeSocket(socket));

            step = "tls";
            SSLContext ctx = verify ? TlsTrust.verifyingContext() : insecureContext();
            SSLEngine engine = ctx.createSSLEngine(certHost, port);
            engine.setUseClientMode(true);
            String protos = System.getenv("SCM_TDS_TLS_PROTOCOLS");
            engine.setEnabledProtocols((protos == null || protos.isBlank())
                ? new String[]{ "TLSv1.2" } : protos.trim().split("\\s*,\\s*"));
            if (verify) {
                SSLParameters p = engine.getSSLParameters();
                p.setEndpointIdentificationAlgorithm("HTTPS");
                engine.setSSLParameters(p);
            }

            doTlsHandshake(engine, rawIn, rawOut);
            if (debug()) {
                SSLSession ss = engine.getSession();
                log("tls " + ss.getProtocol() + " " + ss.getCipherSuite());
                try {
                    java.security.cert.Certificate[] chain = ss.getPeerCertificates();
                    if (chain.length > 0 && chain[0] instanceof java.security.cert.X509Certificate)
                        log("server certificate "
                            + ((java.security.cert.X509Certificate) chain[0]).getSubjectX500Principal());
                } catch (SSLPeerUnverifiedException e) { log("no peer certificate"); }
            }

            SslEngineInputStream  sslIn  = new SslEngineInputStream(rawIn, engine);
            SslEngineOutputStream sslOut = new SslEngineOutputStream(rawOut, engine);
            return new NativeValue(new SchemeSocket(socket, sslIn, sslOut));
        } catch (Exception e) {
            throw new SchemeError(pos, "tds-connect (" + step + "): " + e.getMessage());
        }
    }

    private static SSLContext insecureContext() throws Exception {
        SSLContext ctx = SSLContext.getInstance("TLS");
        ctx.init(null, new TrustManager[]{ new TrustAllX509() }, null);
        return ctx;
    }

    // -------------------------------------------------------------------------
    // PreLogin helpers
    // -------------------------------------------------------------------------

    private static void sendPreLogin(OutputStream out, int encryption) throws IOException {
        byte[] body = {
            0x00, 0x00, 0x0B, 0x00, 0x06,              // VERSION: offset=11, length=6
            0x01, 0x00, 0x11, 0x00, 0x01,              // ENCRYPTION: offset=17, length=1
            (byte)0xFF,                                 // terminator
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,        // VERSION value
            (byte)encryption
        };
        writeTdsPackets(out, (byte)0x12, body);
    }

    // Returns the server's ENCRYPTION option value
    private static int readPreLoginResponse(InputStream in) throws IOException {
        byte[] body = readTdsMessage(in);
        int enc = ENCRYPT_NOT_SUP;
        int i = 0;
        while (i + 4 < body.length && (body[i] & 0xFF) != 0xFF) {
            int token = body[i] & 0xFF;
            int off = ((body[i + 1] & 0xFF) << 8) | (body[i + 2] & 0xFF);
            int len = ((body[i + 3] & 0xFF) << 8) | (body[i + 4] & 0xFF);
            if (token == 0x00 && len >= 4 && off + 4 <= body.length)
                log("server version " + (body[off] & 0xFF) + "." + (body[off + 1] & 0xFF)
                    + "." + (((body[off + 2] & 0xFF) << 8) | (body[off + 3] & 0xFF)));
            if (token == 0x01 && len >= 1 && off < body.length) enc = body[off] & 0xFF;
            i += 5;
        }
        return enc;
    }

    // Writes payload as one TDS message, split into packets of at most 4096 bytes
    private static void writeTdsPackets(OutputStream out, byte type, byte[] payload) throws IOException {
        int max = 4096 - 8;
        int off = 0, id = 1;
        do {
            int n = Math.min(max, payload.length - off);
            boolean last = off + n >= payload.length;
            byte[] hdr = new byte[8];
            hdr[0] = type;
            hdr[1] = (byte)(last ? 0x01 : 0x00);     // EOM
            hdr[2] = (byte)((n + 8) >> 8);
            hdr[3] = (byte)((n + 8) & 0xFF);
            hdr[6] = (byte)id++;
            out.write(hdr);
            out.write(payload, off, n);
            off += n;
        } while (off < payload.length);
        out.flush();
    }

    // Reads one TDS packet; returns {status, body}
    private static Object[] readTdsPacket(InputStream in) throws IOException {
        byte[] hdr = readExact(in, 8);
        int len = ((hdr[2] & 0xFF) << 8) | (hdr[3] & 0xFF);
        return new Object[]{ hdr[1] & 0xFF, readExact(in, len - 8) };
    }

    // Reads packets until EOM and returns the concatenated bodies
    private static byte[] readTdsMessage(InputStream in) throws IOException {
        ByteArrayOutputStream acc = new ByteArrayOutputStream();
        while (true) {
            Object[] p = readTdsPacket(in);
            acc.write((byte[]) p[1]);
            if ((((Integer) p[0]) & 0x01) != 0) return acc.toByteArray();
        }
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
    // TLS handshake (records carried in TDS PRELOGIN 0x12 packets)
    // -------------------------------------------------------------------------

    private static void doTlsHandshake(SSLEngine engine, InputStream rawIn, OutputStream rawOut)
            throws Exception {
        engine.beginHandshake();
        int appBufSize = engine.getSession().getApplicationBufferSize();
        int netBufSize = engine.getSession().getPacketBufferSize();
        ByteBuffer appIn  = ByteBuffer.allocate(appBufSize + 64);
        ByteBuffer netOut = ByteBuffer.allocate(netBufSize + 64);
        ByteBuffer netIn  = ByteBuffer.allocate(netBufSize + 64);
        netIn.flip();                                   // empty, read mode
        ByteBuffer empty  = ByteBuffer.allocate(0);
        ByteArrayOutputStream flight = new ByteArrayOutputStream();

        SSLEngineResult.HandshakeStatus hs = engine.getHandshakeStatus();
        while (hs != SSLEngineResult.HandshakeStatus.FINISHED &&
               hs != SSLEngineResult.HandshakeStatus.NOT_HANDSHAKING) {
            switch (hs) {
                case NEED_WRAP: {
                    netOut.clear();
                    SSLEngineResult res = engine.wrap(empty, netOut);
                    netOut.flip();
                    flight.write(netOut.array(), 0, netOut.limit());
                    hs = res.getHandshakeStatus();
                    // send the collected flight once the engine waits for the server or is done
                    if (hs != SSLEngineResult.HandshakeStatus.NEED_WRAP && flight.size() > 0) {
                        writeTdsPackets(rawOut, (byte)0x12, flight.toByteArray());
                        flight.reset();
                    }
                    break;
                }
                case NEED_UNWRAP: {
                    appIn.clear();
                    SSLEngineResult res = netIn.hasRemaining()
                        ? engine.unwrap(netIn, appIn) : null;
                    if (res == null || res.getStatus() == SSLEngineResult.Status.BUFFER_UNDERFLOW) {
                        // need more data: append the next TDS packet body to netIn
                        byte[] body = (byte[]) readTdsPacket(rawIn)[1];
                        ByteBuffer grown = ByteBuffer.allocate(netIn.remaining() + body.length);
                        grown.put(netIn).put(body).flip();
                        netIn = grown;
                        hs = SSLEngineResult.HandshakeStatus.NEED_UNWRAP;
                    } else if (res.getStatus() == SSLEngineResult.Status.CLOSED) {
                        throw new IOException("TLS closed during handshake");
                    } else {
                        hs = res.getHandshakeStatus();
                    }
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
        if (flight.size() > 0) writeTdsPackets(rawOut, (byte)0x12, flight.toByteArray());
        if (netIn.hasRemaining())
            log("warning: " + netIn.remaining() + " unexpected bytes after TLS handshake");
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
