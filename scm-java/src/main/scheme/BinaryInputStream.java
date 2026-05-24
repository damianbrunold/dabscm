package scheme;

import java.io.BufferedInputStream;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;

public class BinaryInputStream {
    private InputStream stream;
    private int peeked = -2; // -2 = no peek buffered, -1 = EOF
    public boolean isOpen = true;

    public BinaryInputStream(InputStream stream) {
        // Wrap unbuffered streams (e.g. socket input) with a buffer so
        // small reads — readByte in particular — don't pay a syscall
        // per byte. Wire-protocol parsers (postgres, sqlserver) read
        // length prefixes byte-by-byte and are dominated by that
        // overhead without buffering.
        if (stream instanceof BufferedInputStream
                || stream instanceof ByteArrayInputStream) {
            this.stream = stream;
        } else {
            this.stream = new BufferedInputStream(stream, 8192);
        }
    }

    // Bulk read: fills buf[offset..offset+count] from the stream,
    // honouring any peeked byte first. Returns the number of bytes
    // actually read (0 means EOF).
    public int read(byte[] buf, int offset, int count) throws IOException {
        if (!isOpen) throw new SchemeError("read-bytevector: port is closed");
        if (count == 0) return 0;
        int total = 0;
        if (peeked != -2) {
            if (peeked == -1) return 0;
            buf[offset] = (byte) peeked;
            peeked = -2;
            total = 1;
            if (count == 1) return 1;
        }
        while (total < count) {
            int n = stream.read(buf, offset + total, count - total);
            if (n <= 0) break;
            total += n;
        }
        return total;
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
