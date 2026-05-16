namespace scheme;

public class PrimitiveBytevectorAppend : Primitive
{
    public override string Name() => "bytevector-append";
    public override string Info() =>
        "Syntax: (bytevector-append bv ...)\n" +
        "Library: (scheme base)\n" +
        "Description: Returns a newly allocated bytevector whose elements are the concatenation of the elements of the given bytevectors.\n" +
        "Example:\n" +
        "  (bytevector-append #u8(0 1 2) #u8(3 4 5)) => #u8(0 1 2 3 4 5)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        int total = 0;
        foreach (object arg in arguments)
            total += Value.AsBytevector(arg).Length;
        byte[] result = new byte[total];
        int offset = 0;
        foreach (object arg in arguments)
        {
            byte[] bv = Value.AsBytevector(arg);
            Array.Copy(bv, 0, result, offset, bv.Length);
            offset += bv.Length;
        }
        return result;
    }
}
