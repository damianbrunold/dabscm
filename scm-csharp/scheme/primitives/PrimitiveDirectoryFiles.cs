namespace scheme;

public class PrimitiveDirectoryFiles : Primitive
{
    public override string Name()
    {
        return "directory-files";
    }

    public override string Info()
    {
        return
            "Syntax: (directory-files dirname)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns a list of the names (not full paths) of the files in the\n" +
            "  directory dirname, without its subdirectories (directory-entries lists\n" +
            "  both).\n" +
            "Example:\n" +
            "  (directory-files \"/tmp\") => (\"file1.txt\" \"file2.txt\" ...)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var di = new DirectoryInfo(LongPath.Wlp(new String(Value.AsString(arguments[0]))));
        var files = di.GetFiles();
        object result = Value.NIL;
        for (int i = files.Length - 1; i >= 0; i--)
        {
            result = new Pair(files[i].Name.ToCharArray(), result);
        }
        return result;
    }
}
