package scheme;

import java.io.IOException;
import java.io.InputStream;

public class BinaryInputStream {
    private InputStream stream;
    private int peeked = -2; // -2 = no peek buffered, -1 = EOF
    public boolean isOpen = true;

    public BinaryInputStream(InputStream stream) {
        this.stream = stream;
    }

    public int readByte() throws IOException {
        if (!isOpen) throw new SchemeError("read-u8: port is closed");
        if (peeked != -2) {
            int val = peeked;
            peeked = -2;
            return val;
        }
        return stream.read();
    }

    public int peekByte() throws IOException {
        if (!isOpen) throw new SchemeError("peek-u8: port is closed");
        if (peeked == -2) {
            peeked = stream.read();
        }
        return peeked;
    }

    public void close() throws IOException {
        isOpen = false;
        stream.close();
    }
}
