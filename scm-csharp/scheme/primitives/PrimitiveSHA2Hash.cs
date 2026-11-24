using System.Buffers.Binary;
using System.Text;
using System.Security.Cryptography;

namespace scheme;

/// sha224-hash, sha384-hash and sha512-hash (sha256-hash has its own class)
public class PrimitiveSHA2Hash : Primitive
{
    private readonly string name;
    private readonly string algorithm;

    public PrimitiveSHA2Hash(string name, string algorithm)
    {
        this.name = name;
        this.algorithm = algorithm;
    }

    public override string Name() => name;

    public override string Info() =>
        "Syntax: (" + name + " obj)\n" +
        "Library: (scm crypto)\n" +
        "Description: Returns the " + algorithm + " hash of obj as a bytevector. Accepts strings\n" +
        "  (hashed as UTF-8), symbols, or bytevectors.\n" +
        "Example:\n" +
        "  (bytevector->hex (" + name + " \"abc\")) => \"...\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        byte[] b;
        if (Value.IsString(arguments[0]))
            b = Encoding.UTF8.GetBytes(Value.AsString(arguments[0]));
        else if (Value.IsSymbol(arguments[0]))
            b = Encoding.UTF8.GetBytes(Value.AsSymbol(arguments[0]));
        else if (Value.IsBytevector(arguments[0]))
            b = Value.AsBytevector(arguments[0]);
        else
            throw new SchemeError(pos, name + ": cannot hash value");
        return algorithm switch
        {
            "SHA-384" => SHA384.HashData(b),
            "SHA-512" => SHA512.HashData(b),
            _ => Sha224(b),
        };
    }

    // .NET has no SHA-224: SHA-256 with SHA-224's initial values, the first
    // 28 bytes of the result (FIPS 180-4)
    static readonly uint[] K =
    {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    };

    internal static byte[] Sha224(byte[] data)
    {
        uint[] h = { 0xc1059ed8, 0x367cd507, 0x3070dd17, 0xf70e5939, 0xffc00b31, 0x68581511, 0x64f98fa7, 0xbefa4fa4 };
        long bitLen = (long)data.Length * 8;
        int padded = ((data.Length + 9 + 63) / 64) * 64;
        var msg = new byte[padded];
        Array.Copy(data, msg, data.Length);
        msg[data.Length] = 0x80;
        BinaryPrimitives.WriteInt64BigEndian(msg.AsSpan(padded - 8), bitLen);
        var w = new uint[64];
        for (int off = 0; off < padded; off += 64)
        {
            for (int i = 0; i < 16; i++) w[i] = BinaryPrimitives.ReadUInt32BigEndian(msg.AsSpan(off + 4 * i));
            for (int i = 16; i < 64; i++)
            {
                uint s0 = uint.RotateRight(w[i - 15], 7) ^ uint.RotateRight(w[i - 15], 18) ^ (w[i - 15] >> 3);
                uint s1 = uint.RotateRight(w[i - 2], 17) ^ uint.RotateRight(w[i - 2], 19) ^ (w[i - 2] >> 10);
                w[i] = w[i - 16] + s0 + w[i - 7] + s1;
            }
            uint a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
            for (int i = 0; i < 64; i++)
            {
                uint S1 = uint.RotateRight(e, 6) ^ uint.RotateRight(e, 11) ^ uint.RotateRight(e, 25);
                uint ch = (e & f) ^ (~e & g);
                uint t1 = hh + S1 + ch + K[i] + w[i];
                uint S0 = uint.RotateRight(a, 2) ^ uint.RotateRight(a, 13) ^ uint.RotateRight(a, 22);
                uint maj = (a & b) ^ (a & c) ^ (b & c);
                uint t2 = S0 + maj;
                hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
            }
            h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
        }
        var result = new byte[28];
        for (int i = 0; i < 7; i++) BinaryPrimitives.WriteUInt32BigEndian(result.AsSpan(4 * i), h[i]);
        return result;
    }
}
