namespace scheme;

public class PrimitiveAbsolutePath : Primitive
{
    public override string Name()
    {
        return "absolute-path";
    }

    public override string Info()
    {
        return
            "Syntax: (absolute-path path)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns the absolute (fully qualified) form of the given path string.\n" +
            "Example:\n" +
            "  (absolute-path \".\") => \"/current/working/dir\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var path = new String(Value.AsString(arguments[0]));
        return Path.GetFullPath(path).ToCharArray();
    }
}
