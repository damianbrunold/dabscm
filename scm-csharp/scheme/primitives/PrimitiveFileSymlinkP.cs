using System;
using System.IO;

namespace scheme;

public class PrimitiveFileSymlinkP : Primitive
{
    public override string Name()
    {
        return "file-symlink?";
    }

    public override string Info()
    {
        return
            "Syntax: (file-symlink? path)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns #t if path names a symbolic link itself (without following it), otherwise #f. Returns #t even for a dangling link whose target is missing, and #f if path does not exist.\n" +
            "Example:\n" +
            "  (file-symlink? \"/usr/local/bin/python\") => #t";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var path = LongPath.Wlp(new String(Value.AsString(arguments[0])));
        try
        {
            var fi = new FileInfo(path);
            if (fi.Exists || fi.LinkTarget != null)
                return fi.LinkTarget != null ? Value.T : Value.F;
            var di = new DirectoryInfo(path);
            return di.LinkTarget != null ? Value.T : Value.F;
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
