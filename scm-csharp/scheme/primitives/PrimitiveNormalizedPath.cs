namespace scheme;

public class PrimitiveNormalizedPath : Primitive
{
    public override string Name()
    {
        return "normalized-path";
    }

    public override string Info()
    {
        return
            "Syntax: (normalized-path path)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns the normalized form of path. If absolute, returns the full path; if relative, returns the relative path from the current directory.\n" +
            "Example:\n" +
            "  (normalized-path \"./foo/../bar\") => \"bar\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var workdir = Directory.GetCurrentDirectory();
        var path = new String(Value.AsString(arguments[0]));
        if (Path.IsPathRooted(path))
        {
            path = Path.GetFullPath(path);
        }
        else
        {
            path = Path.GetRelativePath(workdir, Path.GetFullPath(path));
        }
        return path.ToCharArray();
    }
}
