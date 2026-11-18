namespace scheme;

public class PrimitiveBaseName : Primitive
{
    public override string Name()
    {
        return "base-name";
    }

    public override string Info()
    {
        return
            "Syntax: (base-name path)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns the file name (including extension) from the given path string, without the directory part.\n" +
            "Example:\n" +
            "  (base-name \"/usr/share/doc/readme.txt\") => \"readme.txt\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var path = TrimTrailingSeparators(new String(Value.AsString(arguments[0])));
        return Path.GetFileName(path).ToCharArray();
    }

    // "/a/b/" -> "/a/b"; the root stays as it is
    internal static string TrimTrailingSeparators(string path)
    {
        int end = path.Length;
        while (end > 1 && (path[end - 1] == '/' || path[end - 1] == Path.DirectorySeparatorChar))
            end--;
        if (end == 1 && (path[0] == '/' || path[0] == Path.DirectorySeparatorChar))
            return path.Substring(0, 1);
        // keep "C:" on Windows
        if (end == 2 && path.Length > 2 && path[1] == ':')
            return path.Substring(0, 3);
        return path.Substring(0, end);
    }
}
