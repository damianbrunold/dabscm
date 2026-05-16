namespace scheme;

public class PrimitiveDirectoryName : Primitive
{
    public override string Name()
    {
        return "directory-name";
    }

    public override string Info()
    {
        return
            "Syntax: (directory-name path)\n" +
            "Library: (scm system)\n" +
            "Description: Returns the directory part of the given path as an absolute path string, or #f if there is no parent directory.\n" +
            "Example:\n" +
            "  (directory-name \"/usr/share/readme.txt\") => \"/usr/share\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var path = new String(Value.AsString(arguments[0]));
        var dirinfo = Directory.GetParent(path);
        if (dirinfo == null) return Value.F;
        return dirinfo.FullName.ToCharArray();
    }
}
