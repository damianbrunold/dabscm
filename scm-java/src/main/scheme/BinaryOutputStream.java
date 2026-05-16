package scheme;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;

public class BinaryOutputStream {
    private OutputStream stream;
    private boolean isBytevectorPort;
    public boolean isOpen = true;

    public BinaryOutputStream(OutputStream stream, boolean isBytevectorPort) {
        this.stream = stream;
        this.isBytevectorPort = isBytevectorPort;
    }

    public void writeByte(byte b) throws IOException {
        if (!isOpen) throw new SchemeError("write-u8: port is closed");
        stream.write(b & 0xFF);
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
