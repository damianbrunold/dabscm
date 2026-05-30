using System;
using System.IO;

namespace scheme;

public class PrimitiveFileLock : Primitive
{
    public override string Name() => "file-lock";

    public override string Info() =>
        "Syntax: (file-lock path)\n" +
        "Library: (scm fs)\n" +
        "Description: Acquires an exclusive, OS-managed advisory lock on the file at\n" +
        "  path, creating the file (and any parent directories) if needed. Returns a\n" +
        "  lock handle on success, or #f if another process already holds the lock.\n" +
        "  Release it with file-unlock; the lock is also released automatically when\n" +
        "  the process exits, so it never goes stale.\n" +
        "Example:\n" +
        "  (define h (file-lock \"/tmp/app.lock\"))\n" +
        "  (when h (file-unlock h))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var path = LongPath.Wlp(new String(Value.AsString(arguments[0])));
        try
        {
            var parent = Path.GetDirectoryName(path);
            if (!string.IsNullOrEmpty(parent))
                Directory.CreateDirectory(parent);
            var stream = new FileStream(path, FileMode.OpenOrCreate,
                                        FileAccess.ReadWrite, FileShare.None);
            return new NativeValue(new SchemeFileLock(stream, path));
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
