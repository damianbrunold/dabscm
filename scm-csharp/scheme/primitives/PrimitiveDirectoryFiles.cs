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
            "Description: Returns a list of file names (not full paths) in the directory dirname.\n" +
            "Example:\n" +
            "  (directory-files \"/tmp\") => (\"file1.txt\" \"file2.txt\" ...)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var di = new DirectoryInfo(new String(Value.AsString(arguments[0])));
        var files = di.GetFiles();
        object result = Value.NIL;
        for (int i = files.Length - 1; i >= 0; i--)
        {
            result = new Pair(files[i].Name.ToCharArray(), result);
        }
        return result;
    }
}
