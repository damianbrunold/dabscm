namespace scheme;

public class PrimitiveRandomAccessFileSize : Primitive
{
    public override string Name() => "random-access-file-size";
    public override string Info() =>
        "Syntax: (random-access-file-size f)\n" +
        "Library: (scm random access)\n" +
        "Description: Returns the current size of random-access file f in bytes.\n" +
        "Example:\n" +
        "  (random-access-file-size f) => 1024";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var f = RandomAccessFileHandle.Of(pos, arguments[0], Name());
        try
        {
            return f.Size();
        }
        catch (SchemeError) { throw; }
        catch (System.Exception e)
        {
            throw new SchemeError(pos, Name() + ": io failure: ~a", e.Message);
        }
    }
}
