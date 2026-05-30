namespace scheme;

public class PrimitiveCopyDirectory : Primitive
{
    public override string Name()
    {
        return "copy-directory";
    }

    public override string Info()
    {
        return
            "Syntax: (copy-directory src dest)\n" +
            "Library: (scm fs)\n" +
            "Description: Recursively copies the directory at src to dest. Returns unspecified on success, #f on failure.\n" +
            "Example:\n" +
            "  (copy-directory \"/src/dir\" \"/dst/dir\")";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var src = LongPath.Wlp(new String(Value.AsString(arguments[0])));
        var dst = LongPath.Wlp(new String(Value.AsString(arguments[1])));
        try
        {
            CopyDirectory(src, dst);
            return new Values();
        }
        catch (Exception)
        {
            return Value.F;
        }
    }

    static void CopyDirectory(string src, string dest)
    {
        var dir = new DirectoryInfo(src);
        if (!dir.Exists) throw new DirectoryNotFoundException("not found");
        DirectoryInfo[] dirs = dir.GetDirectories();
        Directory.CreateDirectory(dest);
        foreach (FileInfo file in dir.GetFiles())
        {
            string destpath = Path.Combine(dest, file.Name);
            file.CopyTo(destpath);
        }
        foreach (DirectoryInfo subDir in dirs)
        {
            string destdir = Path.Combine(dest, subDir.Name);
            CopyDirectory(subDir.FullName, destdir);
        }
    }

}
