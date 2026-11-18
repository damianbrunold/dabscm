namespace scheme;

public class PrimitiveLatin1ToString : Primitive
{
    public override string Name()
    {
        return "latin1->string";
    }

    public override string Info()
    {
        return
            "Syntax: (latin1->string bv [start [end]])\n" +
            "Library: (scm bytevector)\n" +
            "Description: Decodes the bytes of bv (or its range from start to end)\n" +
            "as ISO-8859-1 (Latin-1): each byte becomes the character with the same\n" +
            "code. Never fails.\n" +
            "Example:\n" +
            "  (latin1->string (bytevector #x61 #xE4)) => \"a\\xE4;\"";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        byte[] bv = Value.AsBytevector(arguments[0]);
        int start = arguments.Length > 1 ? IntegerMath.ToInt(arguments[1]) : 0;
        int end = arguments.Length > 2 ? IntegerMath.ToInt(arguments[2]) : bv.Length;
        if (start < 0 || end > bv.Length || start > end)
            throw new SchemeError(pos, "latin1->string: invalid range");
        var result = new char[end - start];
        for (int i = start; i < end; i++) result[i - start] = (char) bv[i];
        return result;
    }
}
