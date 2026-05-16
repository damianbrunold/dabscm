package scheme.primitives;

import java.io.FileOutputStream;
import java.util.zip.ZipOutputStream;

import scheme.NativeValue;
import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.ZipOutputHolder;

public class PrimitiveOpenOutputZipFile extends Primitive {
    @Override
    public String name() {
        return "open-output-zip-file";
    }

    @Override
    public String info() {
        return "Syntax: (open-output-zip-file filename)\n" +
               "Library: (scm core)\n" +
               "Description: Creates a new ZIP archive at the given filename and returns a ZIP writer object. Entries can be added using zip-add-text-entry or zip-add-binary-entry.\n" +
               "Example:\n" +
               "  (define z (open-output-zip-file \"archive.zip\"))\n" +
               "  (zip-add-text-entry z \"hello.txt\" \"Hello, world!\")\n" +
               "  (close-output-zip z)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        String filename = new String(Value.asString(arguments[0]));
        try {
            var strm = new ZipOutputStream(new FileOutputStream(filename));
            return new NativeValue(new ZipOutputHolder(strm, null));
        } catch (Exception e) {
            throw new SchemeError(pos, name() + " failed: ~s", e.getMessage());
        }
    }
}
