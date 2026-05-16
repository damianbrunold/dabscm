namespace scheme;

public class PrimitiveXorKey : Primitive
{
    public override string Name()
    {
        return "xor-key";
    }

    public override string Info()
    {
        return
            "Syntax: (xor-key bv key)\n" +
            "Library: (scm crypto)\n" +
            "Description: Returns a new bytevector produced by XORing each byte of bv with the corresponding byte of key, cycling through key as needed.\n" +
            "Example:\n" +
            "  (xor-key data-bv key-bv) => #u8(...)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var value = Value.AsBytevector(arguments[0]);
        var key = Value.AsBytevector(arguments[1]);
        var result = new byte[value.Length];
        var j = 0;
        for (var i = 0; i < value.Length; i++)
        {
            if (j >= key.Length) j = 0;
            result[i] = (byte) (value[i] ^ key[j]);
            j++;
        }
        return result;
    }
}
