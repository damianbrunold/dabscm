namespace scheme;

public class PrimitiveRandomAccessFileFlush : Primitive
{
    public override string Name() => "random-access-file-flush";
    public override string Info() =>
        "Syntax: (random-access-file-flush f)\n" +
        "Library: (scm random access)\n" +
        "Description: Flushes any buffered writes for random-access file f to the underlying storage. Returns an unspecified value.\n" +
        "Example:\n" +
        "  (random-access-file-flush f)";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var f = RandomAccessFileHandle.Of(pos, arguments[0], Name());
        try
        {
            f.Flush();
            return new Values();
        }
        catch (SchemeError) { throw; }
        catch (System.Exception e)
        {
            throw new SchemeError(pos, Name() + ": io failure: ~a", e.Message);
        }
    }
}
