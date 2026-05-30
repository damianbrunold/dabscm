using System;
using System.IO;

namespace scheme;

public class PrimitiveMakeSymlink : Primitive
{
    public override string Name()
    {
        return "make-symlink";
    }

    public override string Info()
    {
        return
            "Syntax: (make-symlink target linkpath)\n" +
            "Library: (scm fs)\n" +
            "Description: Creates a symbolic link at linkpath whose target is the string target, stored verbatim (target need not exist). Does not replace an existing linkpath. Returns unspecified on success, #f on failure. On Windows, requires symlink-creation privilege (Developer Mode or elevation).\n" +
            "Example:\n" +
            "  (make-symlink \"../bin/python3\" \"/usr/local/bin/python\")";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var target = new String(Value.AsString(arguments[0]));
        var link = new String(Value.AsString(arguments[1]));
        try
        {
            // Classify the target relative to the link's own directory so the
            // correct link type is chosen on Windows. On Unix the distinction is
            // cosmetic. Fall back to the file API for a dangling target. The
            // target string itself is stored verbatim (not Wlp-prefixed).
            var linkFull = LongPath.Wlp(link);
            var linkDir = Path.GetDirectoryName(Path.GetFullPath(link)) ?? ".";
            var resolved = Path.IsPathRooted(target) ? target : Path.Combine(linkDir, target);
            if (Directory.Exists(LongPath.Wlp(resolved)))
                Directory.CreateSymbolicLink(linkFull, target);
            else
                File.CreateSymbolicLink(linkFull, target);
            return new Values();
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
