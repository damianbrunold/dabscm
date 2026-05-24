package scheme;

import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;

public class BinaryOutputStream {
    private OutputStream stream;
    private boolean isBytevectorPort;
    public boolean isOpen = true;

    public BinaryOutputStream(OutputStream stream, boolean isBytevectorPort) {
        // Wrap unbuffered streams (socket OutputStream) so byte-by-
        // byte writes don't pay a syscall per byte. Wire-protocol
        // senders (postgres, sqlserver) build messages with many
        // small writeByte calls; without buffering, multi-MB writes
        // take tens of seconds to drain. Bytevector ports
        // (ByteArrayOutputStream) and already-buffered streams pass
        // through.
        if (isBytevectorPort
                || stream instanceof BufferedOutputStream
                || stream instanceof ByteArrayOutputStream) {
            this.stream = stream;
        } else {
            this.stream = new BufferedOutputStream(stream, 8192);
        }
        this.isBytevectorPort = isBytevectorPort;
    }

    public void writeByte(byte b) throws IOException {
        if (!isOpen) throw new SchemeError("write-u8: port is closed");
        stream.write(b & 0xFF);
    }

    // Bulk write: forwards a contiguous chunk to the underlying stream
    // in one call. PrimitiveWriteBytevector uses this so multi-MB
    // payloads don't go through the per-byte path.
    public void write(byte[] buf, int offset, int count) throws IOException {
        if (!isOpen) throw new SchemeError("write-bytevector: port is closed");
        stream.write(buf, offset, count);
    }

    public void flush() throws IOException {
        if (!isOpen) return;
        stream.flush();
    }

    public byte[] getBytes() {
        if (!isBytevectorPort)
            throw new SchemeError("get-output-bytevector: not a bytevector output port");
        if (stream instanceof ByteArrayOutputStream)
            return ((ByteArrayOutputStream) stream).toByteArray();
        throw new SchemeError("get-output-bytevector: internal error");
    }

    public void close() throws IOException {
        isOpen = false;
        stream.close();
    }
}
