namespace scheme;

public class PrimitiveRandomAccessFileWriteB : Primitive
{
    public override string Name() => "random-access-file-write!";
    public override string Info() =>
        "Syntax: (random-access-file-write! f offset bv [start [end]])\n" +
        "Library: (scm random access)\n" +
        "Description: Writes the bytes bv[start..end) to random-access file f starting at byte offset, extending the file when the write goes past the current end. start defaults to 0 and end to the length of bv. Returns the number of bytes written.\n" +
        "Example:\n" +
        "  (random-access-file-write! f 0 #u8(1 2 3)) => 3";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 5);
        var f = RandomAccessFileHandle.Of(pos, arguments[0], Name());
        long offset = IntegerMath.ToLong(arguments[1]);
        byte[] bv = Value.AsBytevector(arguments[2]);
        int start = arguments.Length > 3 ? IntegerMath.ToInt(arguments[3]) : 0;
        int end = arguments.Length > 4 ? IntegerMath.ToInt(arguments[4]) : bv.Length;
        if (offset < 0) throw new SchemeError(pos, Name() + ": negative offset, ~s", offset);
        if (start < 0 || end > bv.Length || start > end)
            throw new SchemeError(pos, Name() + ": bad start/end (~s ~s) for bytevector of length ~s", start, end, bv.Length);
        try
        {
            return (long)f.Write(offset, bv, start, end);
        }
        catch (SchemeError) { throw; }
        catch (System.Exception e)
        {
            throw new SchemeError(pos, Name() + ": io failure: ~a", e.Message);
        }
    }
}
