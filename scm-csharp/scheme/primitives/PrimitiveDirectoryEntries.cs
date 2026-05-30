using System;
using System.IO;

namespace scheme;

public class PrimitiveDirectoryEntries : Primitive
{
    public override string Name()
    {
        return "directory-entries";
    }

    public override string Info()
    {
        return
            "Syntax: (directory-entries dirname)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns a list of (name . type) pairs for the entries in dirname, where name is the entry name (not a full path) and type is one of the symbols file, directory, or symlink. Symlinks are reported as symlink regardless of what they point to (they are not followed).\n" +
            "Example:\n" +
            "  (directory-entries \"/tmp\") => ((\"a.txt\" . file) (\"sub\" . directory) (\"link\" . symlink) ...)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var dir = LongPath.Wlp(new String(Value.AsString(arguments[0])));
        var di = new DirectoryInfo(dir);
        var entries = di.GetFileSystemInfos();
        object result = Value.NIL;
        for (int i = entries.Length - 1; i >= 0; i--)
        {
            var e = entries[i];
            string type;
            if (e.LinkTarget != null) type = "symlink";
            else if ((e.Attributes & FileAttributes.Directory) != 0) type = "directory";
            else type = "file";
            result = new Pair(new Pair(e.Name.ToCharArray(), Value.Intern(type)), result);
        }
        return result;
    }
}
