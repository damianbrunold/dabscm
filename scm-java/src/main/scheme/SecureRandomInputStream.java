package scheme;

import java.io.InputStream;
import java.security.SecureRandom;

// Endless stream of cryptographically random bytes. Backs the random ports
// of (srfi 271 randomized).
public class SecureRandomInputStream extends InputStream {
    private static final SecureRandom random = new SecureRandom();

    @Override
    public int read() {
        byte[] b = new byte[1];
        random.nextBytes(b);
        return b[0] & 0xff;
    }

    @Override
    public int read(byte[] buf, int off, int len) {
        if (off == 0 && len == buf.length) {
            random.nextBytes(buf);
        } else {
            byte[] tmp = new byte[len];
            random.nextBytes(tmp);
            System.arraycopy(tmp, 0, buf, off, len);
        }
        return len;
    }
}
