namespace scheme;

public class PrimitiveFileSize : Primitive
{
    public override string Name()
    {
        return "file-size";
    }

    public override string Info()
    {
        return
            "Syntax: (file-size file)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns the size of the named file in bytes as an exact integer, or #f if the file cannot be accessed.\n" +
            "Example:\n" +
            "  (file-size \"/etc/hosts\") => 221";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var file = LongPath.Wlp(new String(Value.AsString(arguments[0])));
        try
        {
            return (long) new FileInfo(file).Length;
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
