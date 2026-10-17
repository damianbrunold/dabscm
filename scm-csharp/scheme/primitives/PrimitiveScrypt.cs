using System.Text;
using System.Security.Cryptography;

namespace scheme;

public class PrimitiveScrypt : Primitive
{
    public override string Name() => "scrypt";

    public override string Info() =>
        "Syntax: (scrypt password salt n r p length)\n" +
        "Library: (scm crypto)\n" +
        "Description: Derives a key using scrypt (RFC 7914). Password is a string (UTF-8) or bytevector, salt is a bytevector. n is the CPU/memory cost (a power of 2 greater than 1), r the block size, p the parallelization. Returns a bytevector of given length.\n" +
        "Example:\n" +
        "  (scrypt \"password\" salt-bv 32768 8 1 64) => #u8(...)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 6, 6);
        byte[] password;
        if (Value.IsString(arguments[0]))
            password = Encoding.UTF8.GetBytes(Value.AsString(arguments[0]));
        else
            password = Value.AsBytevector(arguments[0]);
        byte[] salt = Value.AsBytevector(arguments[1]);
        int n = IntegerMath.ToInt(arguments[2]);
        int r = IntegerMath.ToInt(arguments[3]);
        int p = IntegerMath.ToInt(arguments[4]);
        int length = IntegerMath.ToInt(arguments[5]);
        if (n < 2 || (n & (n - 1)) != 0)
            throw new SchemeError(pos, "scrypt: n must be a power of 2 greater than 1");
        if (r < 1 || p < 1 || length < 1)
            throw new SchemeError(pos, "scrypt: r, p and length must be positive");
        if ((long)128 * r * n > (1L << 30) || (long)128 * r * p > int.MaxValue)
            throw new SchemeError(pos, "scrypt: parameters need too much memory");
        return Derive(password, salt, n, r, p, length);
    }

    public static byte[] Derive(byte[] password, byte[] salt, int n, int r, int p, int length)
    {
        int blockLen = 128 * r;
        byte[] b = Rfc2898DeriveBytes.Pbkdf2(password, salt, 1, HashAlgorithmName.SHA256, p * blockLen);
        uint[] x = new uint[32 * r];
        uint[] v = new uint[32 * r * n];
        uint[] y = new uint[32 * r];
        for (int i = 0; i < p; i++)
        {
            int off = i * blockLen;
            for (int k = 0; k < x.Length; k++)
                x[k] = (uint)(b[off + 4 * k] | b[off + 4 * k + 1] << 8 | b[off + 4 * k + 2] << 16 | b[off + 4 * k + 3] << 24);
            RoMix(x, v, y, n, r);
            for (int k = 0; k < x.Length; k++)
            {
                b[off + 4 * k] = (byte)x[k];
                b[off + 4 * k + 1] = (byte)(x[k] >> 8);
                b[off + 4 * k + 2] = (byte)(x[k] >> 16);
                b[off + 4 * k + 3] = (byte)(x[k] >> 24);
            }
        }
        return Rfc2898DeriveBytes.Pbkdf2(password, b, 1, HashAlgorithmName.SHA256, length);
    }

    private static void RoMix(uint[] x, uint[] v, uint[] y, int n, int r)
    {
        int words = 32 * r;
        for (int i = 0; i < n; i++)
        {
            Array.Copy(x, 0, v, i * words, words);
            BlockMix(x, y, r);
        }
        for (int i = 0; i < n; i++)
        {
            int j = (int)(x[words - 16] & (uint)(n - 1));
            int vo = j * words;
            for (int k = 0; k < words; k++)
                x[k] ^= v[vo + k];
            BlockMix(x, y, r);
        }
    }

    // B <- BlockMix(B); y is scratch of the same size.
    private static void BlockMix(uint[] b, uint[] y, int r)
    {
        uint[] t = new uint[16];
        Array.Copy(b, (2 * r - 1) * 16, t, 0, 16);
        for (int i = 0; i < 2 * r; i++)
        {
            for (int k = 0; k < 16; k++)
                t[k] ^= b[i * 16 + k];
            Salsa208(t);
            // even blocks go to the first half, odd blocks to the second
            int dst = ((i & 1) == 0 ? i / 2 : r + i / 2) * 16;
            Array.Copy(t, 0, y, dst, 16);
        }
        Array.Copy(y, 0, b, 0, 32 * r);
    }

    private static uint R(uint a, int b) => (a << b) | (a >> (32 - b));

    private static void Salsa208(uint[] b)
    {
        uint x0 = b[0], x1 = b[1], x2 = b[2], x3 = b[3], x4 = b[4], x5 = b[5], x6 = b[6], x7 = b[7];
        uint x8 = b[8], x9 = b[9], x10 = b[10], x11 = b[11], x12 = b[12], x13 = b[13], x14 = b[14], x15 = b[15];
        for (int i = 0; i < 8; i += 2)
        {
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
