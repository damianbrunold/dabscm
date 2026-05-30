namespace scheme;

public class PrimitiveDirectoryDirectories : Primitive
{
    public override string Name()
    {
        return "directory-directories";
    }

    public override string Info()
    {
        return
            "Syntax: (directory-directories dirname)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns a list of subdirectory names (not full paths) in the directory dirname.\n" +
            "Example:\n" +
            "  (directory-directories \"/usr\") => (\"bin\" \"lib\" \"share\" ...)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var di = new DirectoryInfo(LongPath.Wlp(new String(Value.AsString(arguments[0]))));
        var dirs = di.GetDirectories();
        object result = Value.NIL;
        for (int i = dirs.Length - 1; i >= 0; i--)
        {
            result = new Pair(dirs[i].Name.ToCharArray(), result);
        }
        return result;
    }
}
