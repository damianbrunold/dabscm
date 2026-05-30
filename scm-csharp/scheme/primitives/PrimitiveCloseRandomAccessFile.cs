namespace scheme;

public class PrimitiveCloseRandomAccessFile : Primitive
{
    public override string Name() => "close-random-access-file";
    public override string Info() =>
        "Syntax: (close-random-access-file f)\n" +
        "Library: (scm random access)\n" +
        "Description: Closes random-access file f, flushing and releasing the underlying file. Closing an already-closed handle is harmless. Returns an unspecified value.\n" +
        "Example:\n" +
        "  (close-random-access-file f)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var f = RandomAccessFileHandle.Of(pos, arguments[0], Name());
        try
        {
            f.Close();
            return new Values();
        }
        catch (System.Exception e)
        {
            throw new SchemeError(pos, Name() + ": io failure: ~a", e.Message);
        }
    }
}
