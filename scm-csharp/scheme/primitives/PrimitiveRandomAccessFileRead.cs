namespace scheme;

public class PrimitiveRandomAccessFileRead : Primitive
{
    public override string Name() => "random-access-file-read";
    public override string Info() =>
        "Syntax: (random-access-file-read f offset count)\n" +
        "Library: (scm random access)\n" +
        "Description: Reads up to count bytes from random-access file f starting at byte offset and returns them as a freshly allocated bytevector. The returned bytevector is shorter than count (possibly empty) when the read reaches end of file. Does not affect any other read or write.\n" +
        "Example:\n" +
        "  (random-access-file-read f 0 4) => #u8(1 2 3 4)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        var f = RandomAccessFileHandle.Of(pos, arguments[0], Name());
        long offset = IntegerMath.ToLong(arguments[1]);
        int count = IntegerMath.ToInt(arguments[2]);
        if (offset < 0) throw new SchemeError(pos, Name() + ": negative offset, ~s", offset);
        try
        {
            return f.Read(offset, count);
        }
        catch (SchemeError) { throw; }
        catch (System.Exception e)
        {
            throw new SchemeError(pos, Name() + ": io failure: ~a", e.Message);
        }
    }
}
