package scheme.primitives;

import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.ZipOutputHolder;

public class PrimitiveGetOutputZipBytevector extends Primitive {
    @Override
    public String name() {
        return "get-output-zip-bytevector";
    }

    @Override
    public String info() {
        return "Syntax: (get-output-zip-bytevector zip)\n" +
               "Library: (scm zip)\n" +
               "Description: Returns the contents of an in-memory ZIP archive as a bytevector. " +
               "Must be called after close-output-zip to ensure all entries are flushed.\n" +
               "Example:\n" +
               "  (let ((z (open-output-zip-bytevector)))\n" +
               "    (close-output-zip z)\n" +
               "    (get-output-zip-bytevector z))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        ZipOutputHolder holder = (ZipOutputHolder) Value.asNativeValue(arguments[0]).value;
        if (holder.mem == null)
            throw new SchemeError(pos, "get-output-zip-bytevector: not a bytevector zip port");
        return holder.mem.toByteArray();
    }
}
