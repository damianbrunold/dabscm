package scheme;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;

/**
 * A WebSocket connection (RFC 6455) after the handshake: from ws-accept,
 * ws-connect or an HTTP upgrade (http-websocket-upgrade). One thread
 * receives; any thread may send (sends are serialized). Pings are answered
 * with pongs, fragmented messages are joined, a close frame is answered and
 * ends the connection. The same logic is in scm-csharp/scheme/SchemeWebSocket.cs.
 */
public class SchemeWebSocket {
    public static final long DEFAULT_MAX_MESSAGE_BYTES = 16L * 1024 * 1024;
    /** What receive returns when no frame arrived within the timeout. */
    public static final String TIMEOUT = Value.intern("timeout");

    public final InputStream input;
    public final OutputStream output;
    public final boolean isServer;
    public final Socket socket;          // for receive timeouts; may be null
    public long maxMessageBytes = DEFAULT_MAX_MESSAGE_BYTES;
    private final Object writeLock = new Object();
    private volatile boolean closeSent;
    private volatile boolean closed;
    private static final SecureRandom random = new SecureRandom();

    public SchemeWebSocket(InputStream input, OutputStream output, boolean isServer) {
        this(input, output, isServer, null);
    }

    public SchemeWebSocket(InputStream input, OutputStream output, boolean isServer, Socket socket) {
        this.input = input;
        this.output = output;
        this.isServer = isServer;
        this.socket = socket;
    }

    public boolean isClosed() { return closed; }

    /** The Sec-WebSocket-Accept value for a Sec-WebSocket-Key. */
    public static String acceptKey(String key) {
        try {
            byte[] sha1 = java.security.MessageDigest.getInstance("SHA-1")
                .digest((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").getBytes(StandardCharsets.UTF_8));
            return java.util.Base64.getEncoder().encodeToString(sha1);
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    /**
     * Reads HTTP headers byte by byte up to the empty line (so that no frame
     * bytes behind them are consumed) and returns them, or null at EOF.
     */
    public static String readHeaders(InputStream in) throws IOException {
        ByteArrayOutputStream buf = new ByteArrayOutputStream(512);
        int matched = 0;
        while (matched < 4) {
            int b = in.read();
            if (b < 0) return null;
            buf.write(b);
            if ((matched == 0 || matched == 2) && b == '\r') matched++;
            else if ((matched == 1 || matched == 3) && b == '\n') matched++;
            else matched = (b == '\r') ? 1 : 0;
            if (buf.size() > 64 * 1024) throw new IOException("headers too long");
        }
        return buf.toString(StandardCharsets.ISO_8859_1);
    }

    // --- sending ---

    public void send(int opcode, byte[] payload) throws IOException {
        synchronized (writeLock) {
            if (closeSent) throw new IOException("the connection is closed");
            writeFrame(opcode, payload);
        }
    }

    private void writeFrame(int opcode, byte[] payload) throws IOException {
        int len = payload.length;
        boolean mask = !isServer;           // clients mask, servers don't
        ByteArrayOutputStream f = new ByteArrayOutputStream(len + 14);
        f.write(0x80 | opcode);
        int maskBit = mask ? 0x80 : 0x00;
        if (len < 126) {
            f.write(maskBit | len);
        } else if (len < 65536) {
            f.write(maskBit | 126);
            f.write(len >> 8);
            f.write(len & 0xFF);
        } else {
            f.write(maskBit | 127);
            for (int i = 7; i >= 0; i--) f.write((int) (((long) len >> (i * 8)) & 0xFF));
        }
        if (mask) {
            byte[] key = new byte[4];
            random.nextBytes(key);
            f.write(key, 0, 4);
            for (int i = 0; i < len; i++) f.write(payload[i] ^ key[i % 4]);
        } else {
            f.write(payload, 0, len);
        }
        output.write(f.toByteArray());
        output.flush();
    }

    /** Sends a close frame (once) with a status code; the peer's answer ends receive. */
    public void close(int code) {
        synchronized (writeLock) {
            if (closeSent) return;
            closeSent = true;
            try {
                writeFrame(0x8, new byte[] {(byte) (code >> 8), (byte) code});
            } catch (IOException ignored) {
            }
        }
    }

    /** Closes the connection without the close handshake. */
    public void shutdown() {
        closed = true;
        closeSent = true;
        try {
            if (socket != null) socket.close();
            else output.close();
        } catch (IOException ignored) {
        }
    }

    // --- receiving ---

    private int readByte() throws IOException {
        int b = input.read();
        if (b < 0) throw new java.io.EOFException();
        return b;
    }

    private void readFully(byte[] buf, int off, int len) throws IOException {
        while (len > 0) {
            int r = input.read(buf, off, len);
            if (r < 0) throw new java.io.EOFException();
            off += r;
            len -= r;
        }
    }

    /**
     * The next message: a char[] (text), a byte[] (binary), Boolean.FALSE
     * when the connection has closed, or TIMEOUT when timeoutMs > 0 and no
     * frame began within it.
     */
    public Object receive(int timeoutMs) {
        if (closed) return Value.F;
        ByteArrayOutputStream message = null;
        int messageOpcode = 0;
        try {
            while (true) {
                int b0;
                if (timeoutMs > 0 && socket != null && message == null) {
                    socket.setSoTimeout(timeoutMs);
                    try {
                        b0 = readByte();
                    } catch (SocketTimeoutException e) {
                        return TIMEOUT;
                    } finally {
                        socket.setSoTimeout(0);
                    }
                } else {
                    b0 = readByte();
                }
                int b1 = readByte();
                boolean fin = (b0 & 0x80) != 0;
                int opcode = b0 & 0x0F;
                boolean masked = (b1 & 0x80) != 0;
                long len = b1 & 0x7F;
                if (len == 126) {
                    len = (readByte() << 8) | readByte();
                } else if (len == 127) {
                    len = 0;
                    for (int i = 0; i < 8; i++) len = (len << 8) | readByte();
                }
                if (isServer && !masked) return fail(1002);     // clients must mask
                boolean control = opcode >= 0x8;
                if (control && (len > 125 || !fin)) return fail(1002);
                long total = (message == null ? 0 : message.size()) + len;
                if (len < 0 || total > maxMessageBytes) return fail(1009);
                byte[] key = new byte[4];
                if (masked) readFully(key, 0, 4);
                byte[] payload = new byte[(int) len];
                readFully(payload, 0, (int) len);
                if (masked) for (int i = 0; i < payload.length; i++) payload[i] ^= key[i % 4];
                switch (opcode) {
                    case 0x9:                                       // ping
                        synchronized (writeLock) { if (!closeSent) writeFrame(0xA, payload); }
                        continue;
                    case 0xA:                                       // pong
                        continue;
                    case 0x8: {                                     // close
                        int code = payload.length >= 2 ? ((payload[0] & 0xFF) << 8) | (payload[1] & 0xFF) : 1000;
                        close(code == 1005 || code == 1006 ? 1000 : code);
                        shutdown();
                        return Value.F;
                    }
                    case 0x0:                                       // continuation
                        if (message == null) return fail(1002);
                        message.write(payload, 0, payload.length);
                        break;
                    case 0x1: case 0x2:
                        if (message != null) return fail(1002);
                        messageOpcode = opcode;
                        message = new ByteArrayOutputStream(payload.length);
                        message.write(payload, 0, payload.length);
                        break;
                    default:
                        return fail(1002);
                }
                if (fin) {
                    byte[] data = message.toByteArray();
                    return messageOpcode == 0x1 ? new String(data, StandardCharsets.UTF_8).toCharArray() : data;
                }
            }
        } catch (IOException e) {
            shutdown();
            return Value.F;
        }
    }

    private Object fail(int code) {
        close(code);
        shutdown();
        return Value.F;
    }

    @Override
    public String toString() { return "#<websocket>"; }
}
