using System;
using System.IO;

namespace scheme;

public class PrimitiveReadSymlink : Primitive
{
    public override string Name()
    {
        return "read-symlink";
    }

    public override string Info()
    {
        return
            "Syntax: (read-symlink path)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns the raw target string stored in the symbolic link at path, exactly as recorded (not resolved or canonicalized). Returns #f if path is not a symbolic link or cannot be read.\n" +
            "Example:\n" +
            "  (read-symlink \"/usr/local/bin/python\") => \"../bin/python3\"";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var path = LongPath.Wlp(new String(Value.AsString(arguments[0])));
        try
        {
            // LinkTarget returns the immediate, unresolved target (the raw link
            // text). Do not use ResolveLinkTarget(path, true), which follows the
            // whole chain.
            var target = new FileInfo(path).LinkTarget;
            if (target == null)
                target = new DirectoryInfo(path).LinkTarget;
            return target == null ? Value.F : LongPath.Strip(target).ToCharArray();
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
