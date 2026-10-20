package scheme;

import java.math.BigInteger;

// Shared by the (scm bytevector) primitives: multi-byte integers and IEEE
// floats at a byte index, in either byte order.
public class BytevectorNumbers {

    public static int index(SourcePos pos, String who, byte[] bv, Object k, int size) {
        if (!(k instanceof Long)) throw new SchemeError(pos, who + ": index out of range: ~s", k);
        long i = (Long) k;
        if (i < 0 || i + size > bv.length) throw new SchemeError(pos, who + ": index out of range: ~s", k);
        return (int) i;
    }

    public static boolean little(SourcePos pos, String who, Object endianness) {
        if (endianness instanceof String) {
            if (endianness.equals("little")) return true;
            if (endianness.equals("big")) return false;
        }
        throw new SchemeError(pos, who + ": endianness must be big or little: ~s", endianness);
    }

    public static long readU(byte[] bv, int k, int size, boolean little) {
        long v = 0;
        for (int i = 0; i < size; i++)
            v = (v << 8) | (bv[k + (little ? size - 1 - i : i)] & 0xFF);
        return v;
    }

    public static long readS(byte[] bv, int k, int size, boolean little) {
        int shift = 64 - 8 * size;
        return (readU(bv, k, size, little) << shift) >> shift;
    }

    public static void writeInt(SourcePos pos, String who, byte[] bv, int k, int size,
                                boolean signed, Object n, boolean little) {
        int bits = 8 * size;
        long min = signed ? -(1L << (bits - 1)) : 0;
        long max = signed ? (1L << (bits - 1)) - 1 : (1L << bits) - 1;
        if (!(n instanceof Long) || (Long) n < min || (Long) n > max) {
            if (n instanceof Long || n instanceof BigInteger)
                throw new SchemeError(pos, who + ": value out of range: ~s", n);
            throw new SchemeError(pos, who + ": not an exact integer: ~s", n);
        }
        long v = (Long) n;
        for (int i = 0; i < size; i++)
            bv[k + (little ? i : size - 1 - i)] = (byte) (v >> (8 * i));
    }

    public static float readSingle(byte[] bv, int k, boolean little) {
        return Float.intBitsToFloat((int) readU(bv, k, 4, little));
    }

    public static double readDouble(byte[] bv, int k, boolean little) {
        long v = 0;
        for (int i = 0; i < 8; i++)
            v = (v << 8) | (bv[k + (little ? 7 - i : i)] & 0xFF);
        return Double.longBitsToDouble(v);
    }

    public static void writeSingle(byte[] bv, int k, float x, boolean little) {
        int v = Float.floatToRawIntBits(x);
        for (int i = 0; i < 4; i++)
            bv[k + (little ? i : 3 - i)] = (byte) (v >> (8 * i));
    }

    public static void writeDouble(byte[] bv, int k, double x, boolean little) {
        long v = Double.doubleToRawLongBits(x);
        for (int i = 0; i < 8; i++)
            bv[k + (little ? i : 7 - i)] = (byte) (v >> (8 * i));
    }
}
