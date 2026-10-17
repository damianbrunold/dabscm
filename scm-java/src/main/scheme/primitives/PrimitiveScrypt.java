package scheme.primitives;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import scheme.*;

public class PrimitiveScrypt extends Primitive {
    @Override
    public String name() { return "scrypt"; }

    @Override
    public String info() {
        return "Syntax: (scrypt password salt n r p length)\n" +
               "Library: (scm crypto)\n" +
               "Description: Derives a key using scrypt (RFC 7914). Password is a string (UTF-8) or bytevector, salt is a bytevector. n is the CPU/memory cost (a power of 2 greater than 1), r the block size, p the parallelization. Returns a bytevector of given length.\n" +
               "Example:\n" +
               "  (scrypt \"password\" salt-bv 32768 8 1 64) => #u8(...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 6, 6);
        byte[] password;
        if (Value.isString(arguments[0]))
            password = new String(Value.asString(arguments[0])).getBytes(StandardCharsets.UTF_8);
        else
            password = Value.asBytevector(arguments[0]);
        byte[] salt = Value.asBytevector(arguments[1]);
        int n = IntegerMath.toInt(arguments[2]);
        int r = IntegerMath.toInt(arguments[3]);
        int p = IntegerMath.toInt(arguments[4]);
        int length = IntegerMath.toInt(arguments[5]);
        if (n < 2 || (n & (n - 1)) != 0)
            throw new SchemeError(pos, "scrypt: n must be a power of 2 greater than 1");
        if (r < 1 || p < 1 || length < 1)
            throw new SchemeError(pos, "scrypt: r, p and length must be positive");
        if (128L * r * n > (1L << 30) || 128L * r * p > Integer.MAX_VALUE)
            throw new SchemeError(pos, "scrypt: parameters need too much memory");
        try {
            return derive(password, salt, n, r, p, length);
        } catch (GeneralSecurityException e) {
            throw new SchemeError(pos, "scrypt: " + e.getMessage());
        }
    }

    public static byte[] derive(byte[] password, byte[] salt, int n, int r, int p, int length)
            throws GeneralSecurityException {
        int blockLen = 128 * r;
        byte[] b = pbkdf2Once(password, salt, p * blockLen);
        int[] x = new int[32 * r];
        int[] v = new int[32 * r * n];
        int[] y = new int[32 * r];
        for (int i = 0; i < p; i++) {
            int off = i * blockLen;
            for (int k = 0; k < x.length; k++)
                x[k] = (b[off + 4 * k] & 0xff) | (b[off + 4 * k + 1] & 0xff) << 8
                     | (b[off + 4 * k + 2] & 0xff) << 16 | (b[off + 4 * k + 3] & 0xff) << 24;
            roMix(x, v, y, n, r);
            for (int k = 0; k < x.length; k++) {
                b[off + 4 * k] = (byte) x[k];
                b[off + 4 * k + 1] = (byte) (x[k] >>> 8);
                b[off + 4 * k + 2] = (byte) (x[k] >>> 16);
                b[off + 4 * k + 3] = (byte) (x[k] >>> 24);
            }
        }
        return pbkdf2Once(password, b, length);
    }

    // PBKDF2-HMAC-SHA256 with one iteration over raw password bytes
    // (PBEKeySpec only takes chars, which cannot carry arbitrary bytes).
    private static byte[] pbkdf2Once(byte[] password, byte[] salt, int length)
            throws GeneralSecurityException {
        Mac mac = Mac.getInstance("HmacSHA256");
        // SecretKeySpec rejects an empty key; HMAC zero-pads the key, so a
        // single zero byte is the same key.
        mac.init(new SecretKeySpec(password.length == 0 ? new byte[1] : password, "HmacSHA256"));
        byte[] out = new byte[length];
        int pos = 0;
        for (int block = 1; pos < length; block++) {
            mac.update(salt);
            mac.update(new byte[] { (byte) (block >>> 24), (byte) (block >>> 16), (byte) (block >>> 8), (byte) block });
            byte[] u = mac.doFinal();
            int k = Math.min(u.length, length - pos);
            System.arraycopy(u, 0, out, pos, k);
            pos += k;
        }
        return out;
    }

    private static void roMix(int[] x, int[] v, int[] y, int n, int r) {
        int words = 32 * r;
        for (int i = 0; i < n; i++) {
            System.arraycopy(x, 0, v, i * words, words);
            blockMix(x, y, r);
        }
        for (int i = 0; i < n; i++) {
            int j = x[words - 16] & (n - 1);
            int vo = j * words;
            for (int k = 0; k < words; k++)
                x[k] ^= v[vo + k];
            blockMix(x, y, r);
        }
    }

    // B <- BlockMix(B); y is scratch of the same size.
    private static void blockMix(int[] b, int[] y, int r) {
        int[] t = new int[16];
        System.arraycopy(b, (2 * r - 1) * 16, t, 0, 16);
        for (int i = 0; i < 2 * r; i++) {
            for (int k = 0; k < 16; k++)
                t[k] ^= b[i * 16 + k];
            salsa208(t);
            // even blocks go to the first half, odd blocks to the second
            int dst = ((i & 1) == 0 ? i / 2 : r + i / 2) * 16;
            System.arraycopy(t, 0, y, dst, 16);
        }
        System.arraycopy(y, 0, b, 0, 32 * r);
    }

    private static int R(int a, int b) { return Integer.rotateLeft(a, b); }

    private static void salsa208(int[] b) {
        int x0 = b[0], x1 = b[1], x2 = b[2], x3 = b[3], x4 = b[4], x5 = b[5], x6 = b[6], x7 = b[7];
        int x8 = b[8], x9 = b[9], x10 = b[10], x11 = b[11], x12 = b[12], x13 = b[13], x14 = b[14], x15 = b[15];
        for (int i = 0; i < 8; i += 2) {
            x4 ^= R(x0 + x12, 7); x8 ^= R(x4 + x0, 9);
            x12 ^= R(x8 + x4, 13); x0 ^= R(x12 + x8, 18);
            x9 ^= R(x5 + x1, 7); x13 ^= R(x9 + x5, 9);
            x1 ^= R(x13 + x9, 13); x5 ^= R(x1 + x13, 18);
            x14 ^= R(x10 + x6, 7); x2 ^= R(x14 + x10, 9);
            x6 ^= R(x2 + x14, 13); x10 ^= R(x6 + x2, 18);
            x3 ^= R(x15 + x11, 7); x7 ^= R(x3 + x15, 9);
            x11 ^= R(x7 + x3, 13); x15 ^= R(x11 + x7, 18);
            x1 ^= R(x0 + x3, 7); x2 ^= R(x1 + x0, 9);
            x3 ^= R(x2 + x1, 13); x0 ^= R(x3 + x2, 18);
            x6 ^= R(x5 + x4, 7); x7 ^= R(x6 + x5, 9);
            x4 ^= R(x7 + x6, 13); x5 ^= R(x4 + x7, 18);
            x11 ^= R(x10 + x9, 7); x8 ^= R(x11 + x10, 9);
            x9 ^= R(x8 + x11, 13); x10 ^= R(x9 + x8, 18);
            x12 ^= R(x15 + x14, 7); x13 ^= R(x12 + x15, 9);
            x14 ^= R(x13 + x12, 13); x15 ^= R(x14 + x13, 18);
        }
        b[0] += x0; b[1] += x1; b[2] += x2; b[3] += x3; b[4] += x4; b[5] += x5; b[6] += x6; b[7] += x7;
        b[8] += x8; b[9] += x9; b[10] += x10; b[11] += x11; b[12] += x12; b[13] += x13; b[14] += x14; b[15] += x15;
    }
}
