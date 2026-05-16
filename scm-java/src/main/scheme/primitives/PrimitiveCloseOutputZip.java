package scheme.primitives;

import java.util.zip.ZipOutputStream;

import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.Values;
import scheme.ZipOutputHolder;

public class PrimitiveCloseOutputZip extends Primitive {
    @Override
    public String name() {
        return "close-output-zip";
    }

    @Override
    public String info() {
        return "Syntax: (close-output-zip zip)\n" +
               "Library: (scm core)\n" +
               "Description: Closes the given zip output archive, flushing and releasing all underlying resources.\n" +
               "Example:\n" +
               "  (let ((z (open-output-zip-file \"archive.zip\")))\n" +
               "    (close-output-zip z))";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            ZipOutputHolder holder = (ZipOutputHolder) Value.asNativeValue(arguments[0]).value;
            holder.zip.close();
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + " failed: ~s", e.getMessage());
        }
    }
}
