package scheme.primitives;

import scheme.*;

public class PrimitiveFileUnlock extends Primitive {
    @Override
    public String name() {
        return "file-unlock";
    }

    @Override
    public String info() {
        return "Syntax: (file-unlock handle)\n" +
               "Library: (scm fs)\n" +
               "Description: Releases a lock acquired by file-lock. Returns #t if handle was a\n" +
               "  live file lock, #f otherwise.\n" +
               "Example:\n" +
               "  (file-unlock (file-lock \"/tmp/app.lock\")) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var nv = Value.asNativeValue(arguments[0]);
        if (nv.value instanceof SchemeFileLock) {
            ((SchemeFileLock) nv.value).release();
            return Value.T;
        }
        return Value.F;
    }
}
