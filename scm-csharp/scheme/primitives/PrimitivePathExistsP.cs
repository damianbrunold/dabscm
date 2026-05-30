using System;
using System.IO;

namespace scheme;

public class PrimitivePathExistsP : Primitive
{
    public override string Name()
    {
        return "path-exists?";
    }

    public override string Info()
    {
        return
            "Syntax: (path-exists? path)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns #t if path exists as a file, directory, or symbolic link (a dangling link still counts), without following links; otherwise #f. This is the lexists-style check.\n" +
            "Example:\n" +
            "  (path-exists? \"/etc/hosts\") => #t";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var path = LongPath.Wlp(new String(Value.AsString(arguments[0])));
        try
        {
            if (File.Exists(path) || Directory.Exists(path)) return Value.T;
            if (new FileInfo(path).LinkTarget != null) return Value.T;
            if (new DirectoryInfo(path).LinkTarget != null) return Value.T;
            return Value.F;
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
