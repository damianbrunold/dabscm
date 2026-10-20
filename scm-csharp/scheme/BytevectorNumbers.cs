using System.Buffers.Binary;
using System.Numerics;

namespace scheme;

// Shared by the (scm bytevector) primitives: multi-byte integers and IEEE
// floats at a byte index, in either byte order.
internal static class BytevectorNumbers
{
    public static int Index(SourcePos? pos, string who, byte[] bv, object k, int size)
    {
        if (k is not long i || i < 0 || i + size > bv.Length)
            throw new SchemeError(pos, who + ": index out of range: ~s", k);
        return (int)i;
    }

    public static bool Little(SourcePos? pos, string who, object endianness)
    {
        if (endianness is string s)
        {
            if (s == "little") return true;
            if (s == "big") return false;
        }
        throw new SchemeError(pos, who + ": endianness must be big or little: ~s", endianness);
    }

    public static ulong ReadU(byte[] bv, int k, int size, bool little)
    {
        ulong v = 0;
        for (int i = 0; i < size; i++)
            v = (v << 8) | bv[k + (little ? size - 1 - i : i)];
        return v;
    }

    public static long ReadS(byte[] bv, int k, int size, bool little)
    {
        int shift = 64 - 8 * size;
        return ((long)ReadU(bv, k, size, little) << shift) >> shift;
    }

    public static void WriteInt(SourcePos? pos, string who, byte[] bv, int k, int size,
                                bool signed, object n, bool little)
    {
        long bits = 8 * size;
        long min = signed ? -(1L << (int)(bits - 1)) : 0;
        long max = signed ? (1L << (int)(bits - 1)) - 1 : (1L << (int)bits) - 1;
        if (n is not long v || v < min || v > max)
        {
            if (n is long || n is BigInteger)
                throw new SchemeError(pos, who + ": value out of range: ~s", n);
            throw new SchemeError(pos, who + ": not an exact integer: ~s", n);
        }
        for (int i = 0; i < size; i++)
            bv[k + (little ? i : size - 1 - i)] = (byte)(v >> (8 * i));
    }

    public static float ReadSingle(byte[] bv, int k, bool little)
    {
        var span = new ReadOnlySpan<byte>(bv, k, 4);
        return little ? BinaryPrimitives.ReadSingleLittleEndian(span)
                      : BinaryPrimitives.ReadSingleBigEndian(span);
    }

    public static double ReadDouble(byte[] bv, int k, bool little)
    {
        var span = new ReadOnlySpan<byte>(bv, k, 8);
        return little ? BinaryPrimitives.ReadDoubleLittleEndian(span)
                      : BinaryPrimitives.ReadDoubleBigEndian(span);
    }

    public static void WriteSingle(byte[] bv, int k, float x, bool little)
    {
        var span = new Span<byte>(bv, k, 4);
        if (little) BinaryPrimitives.WriteSingleLittleEndian(span, x);
        else BinaryPrimitives.WriteSingleBigEndian(span, x);
    }

    public static void WriteDouble(byte[] bv, int k, double x, bool little)
    {
        var span = new Span<byte>(bv, k, 8);
        if (little) BinaryPrimitives.WriteDoubleLittleEndian(span, x);
        else BinaryPrimitives.WriteDoubleBigEndian(span, x);
    }
}
