namespace scheme;

public class PrimitiveFileUnlock : Primitive
{
    public override string Name() => "file-unlock";

    public override string Info() =>
        "Syntax: (file-unlock handle)\n" +
        "Library: (scm fs)\n" +
        "Description: Releases a lock acquired by file-lock. Returns #t if handle was a\n" +
        "  live file lock, #f otherwise.\n" +
        "Example:\n" +
        "  (file-unlock (file-lock \"/tmp/app.lock\")) => #t";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var nv = Value.AsNativeValue(arguments[0]);
        if (nv.value is SchemeFileLock fl)
        {
            fl.Release();
            return Value.T;
        }
        return Value.F;
    }
}
