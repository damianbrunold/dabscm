package scheme;

import java.io.InputStream;

// Endless ChaCha20 keystream (20 rounds, the original 64-bit block counter
// and 64-bit nonce layout, nonce fixed at zero). Backs the deterministic
// random ports of (srfi 271 determinized). For block counters < 2^32 the
// output equals RFC 8439 ChaCha20 with an all-zero nonce.
//
// The position is (counter, offset): the next byte returned is byte
// `offset` (0..63) of keystream block `counter`. It is exact as long as the
// stream is read unbuffered, which is why BinaryInputStream must not wrap it.
public class ChaCha20InputStream extends InputStream {
    private final byte[] key;
    private final int[] input = new int[16];
    private final int[] x = new int[16];
    private final byte[] block = new byte[64];
    private long counter;
    private int offset;

    public ChaCha20InputStream(byte[] key, long counter, int offset) {
        if (key.length != 32)
            throw new SchemeError("chacha20: key must be 32 bytes");
        if (offset < 0 || offset > 63)
            throw new SchemeError("chacha20: offset must be in 0..63");
        this.key = key.clone();
        input[0] = 0x61707865;
        input[1] = 0x3320646e;
        input[2] = 0x79622d32;
        input[3] = 0x6b206574;
        for (int i = 0; i < 8; i++) {
            input[4 + i] = (key[4 * i] & 0xff)
                | (key[4 * i + 1] & 0xff) << 8
                | (key[4 * i + 2] & 0xff) << 16
                | (key[4 * i + 3] & 0xff) << 24;
        }
        this.counter = counter;
        this.offset = offset;
        generateBlock();
    }

    public byte[] getKey() { return key.clone(); }
    public long getCounter() { return counter; }
    public int getOffset() { return offset; }

    private static int rotl(int v, int c) {
        return (v << c) | (v >>> (32 - c));
    }

    private void quarterRound(int a, int b, int c, int d) {
        x[a] += x[b]; x[d] = rotl(x[d] ^ x[a], 16);
        x[c] += x[d]; x[b] = rotl(x[b] ^ x[c], 12);
        x[a] += x[b]; x[d] = rotl(x[d] ^ x[a], 8);
        x[c] += x[d]; x[b] = rotl(x[b] ^ x[c], 7);
    }

    private void generateBlock() {
        input[12] = (int) counter;
        input[13] = (int) (counter >>> 32);
        input[14] = 0;
        input[15] = 0;
        System.arraycopy(input, 0, x, 0, 16);
        for (int i = 0; i < 10; i++) {
            quarterRound(0, 4, 8, 12);
            quarterRound(1, 5, 9, 13);
            quarterRound(2, 6, 10, 14);
            quarterRound(3, 7, 11, 15);
            quarterRound(0, 5, 10, 15);
            quarterRound(1, 6, 11, 12);
            quarterRound(2, 7, 8, 13);
            quarterRound(3, 4, 9, 14);
        }
        for (int i = 0; i < 16; i++) {
            int v = x[i] + input[i];
            block[4 * i] = (byte) v;
            block[4 * i + 1] = (byte) (v >>> 8);
            block[4 * i + 2] = (byte) (v >>> 16);
            block[4 * i + 3] = (byte) (v >>> 24);
        }
    }

    private void advance(int n) {
        offset += n;
        if (offset == 64) {
            counter++;
            offset = 0;
            generateBlock();
        }
    }

    @Override
    public int read() {
        int b = block[offset] & 0xff;
        advance(1);
        return b;
    }

    @Override
    public int read(byte[] buf, int off, int len) {
        int done = 0;
        while (done < len) {
            int n = Math.min(len - done, 64 - offset);
            System.arraycopy(block, offset, buf, off + done, n);
            done += n;
            advance(n);
        }
        return len;
    }
}
