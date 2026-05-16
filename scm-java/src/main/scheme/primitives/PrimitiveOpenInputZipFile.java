package scheme.primitives;

import java.util.zip.ZipFile;

import scheme.NativeValue;
import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.ZipInputHolder;

public class PrimitiveOpenInputZipFile extends Primitive {
    @Override
    public String name() {
        return "open-input-zip-file";
    }

    @Override
    public String info() {
        return "Syntax: (open-input-zip-file filename)\n" +
               "Library: (scm zip)\n" +
               "Description: Opens an existing ZIP archive at filename for reading and returns a ZIP reader object.\n" +
               "Example:\n" +
               "  (define z (open-input-zip-file \"archive.zip\"))\n" +
               "  (zip-entry-names z)\n" +
               "  (close-input-zip z)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            String filename = new String(Value.asString(arguments[0]));
            return new NativeValue(new ZipInputHolder(new ZipFile(filename)));
        } catch (Exception e) {
            throw new SchemeError(pos, name() + " failed: ~s", e.getMessage());
        }
    }
}
