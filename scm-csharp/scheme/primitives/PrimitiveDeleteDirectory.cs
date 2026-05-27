namespace scheme;

public class PrimitiveDeleteDirectory : Primitive
{
    public override string Name()
    {
        return "delete-directory";
    }

    public override string Info()
    {
        return
            "Syntax: (delete-directory dir)\n" +
            "Library: (scm fs)\n" +
            "Description: Recursively deletes the directory at dir. Returns unspecified on success, #f on failure.\n" +
            "Example:\n" +
            "  (delete-directory \"/tmp/old-dir\")";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var dir = new String(Value.AsString(arguments[0]));
        try
        {
            Directory.Delete(dir, true);
            return new Values();
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
