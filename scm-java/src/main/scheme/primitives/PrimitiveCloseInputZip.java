package scheme.primitives;

import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.Values;
import scheme.ZipInputHolder;

public class PrimitiveCloseInputZip extends Primitive {
    @Override
    public String name() {
        return "close-input-zip";
    }

    @Override
    public String info() {
        return "Syntax: (close-input-zip zip)\n" +
               "Library: (scm zip)\n" +
               "Description: Closes the given ZIP input archive, releasing all underlying resources.\n" +
               "Example:\n" +
               "  (let ((z (open-input-zip-file \"archive.zip\")))\n" +
               "    (close-input-zip z))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            ZipInputHolder holder = (ZipInputHolder) Value.asNativeValue(arguments[0]).value;
            holder.zip.close();
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + " failed: ~s", e.getMessage());
        }
    }
}
