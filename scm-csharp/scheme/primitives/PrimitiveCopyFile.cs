namespace scheme;

public class PrimitiveCopyFile : Primitive
{
    public override string Name()
    {
        return "copy-file";
    }

    public override string Info()
    {
        return
            "Syntax: (copy-file src dest)\n" +
            "Library: (scm fs)\n" +
            "Description: Copies the file at src to dest, overwriting dest if it exists. Returns unspecified on success, #f on failure.\n" +
            "Example:\n" +
            "  (copy-file \"data.txt\" \"backup.txt\")";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var src = LongPath.Wlp(new String(Value.AsString(arguments[0])));
        var dst = LongPath.Wlp(new String(Value.AsString(arguments[1])));
        try
        {
            File.Copy(src, dst, true);
            return new Values();
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
