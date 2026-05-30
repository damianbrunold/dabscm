namespace scheme;

public class PrimitiveRandomAccessFileTruncateB : Primitive
{
    public override string Name() => "random-access-file-truncate!";
    public override string Info() =>
        "Syntax: (random-access-file-truncate! f size)\n" +
        "Library: (scm random access)\n" +
        "Description: Sets the length of random-access file f to size bytes. Shrinks the file when size is smaller than the current length; extends it with zero bytes when larger. Returns an unspecified value.\n" +
        "Example:\n" +
        "  (random-access-file-truncate! f 0)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var f = RandomAccessFileHandle.Of(pos, arguments[0], Name());
        long size = IntegerMath.ToLong(arguments[1]);
        if (size < 0) throw new SchemeError(pos, Name() + ": negative size, ~s", size);
        try
        {
            f.Truncate(size);
            return new Values();
        }
        catch (SchemeError) { throw; }
        catch (System.Exception e)
        {
            throw new SchemeError(pos, Name() + ": io failure: ~a", e.Message);
        }
    }
}
