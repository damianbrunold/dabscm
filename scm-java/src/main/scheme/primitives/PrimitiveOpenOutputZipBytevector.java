package scheme.primitives;

import java.io.ByteArrayOutputStream;
import java.util.zip.ZipOutputStream;

import scheme.NativeValue;
import scheme.Primitive;
import scheme.SourcePos;
import scheme.ZipOutputHolder;

public class PrimitiveOpenOutputZipBytevector extends Primitive {
    @Override
    public String name() {
        return "open-output-zip-bytevector";
    }

    @Override
    public String info() {
        return "Syntax: (open-output-zip-bytevector)\n" +
               "Library: (scm zip)\n" +
               "Description: Creates a new in-memory ZIP archive and returns a ZIP writer object. " +
               "After writing entries and calling close-output-zip, use get-output-zip-bytevector to retrieve the bytes.\n" +
               "Example:\n" +
               "  (let ((z (open-output-zip-bytevector)))\n" +
               "    (zip-add-text-entry z \"hello.txt\")\n" +
               "    (close-output-zip z)\n" +
               "    (get-output-zip-bytevector z))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        var mem = new ByteArrayOutputStream();
        var zip = new ZipOutputStream(mem);
        return new NativeValue(new ZipOutputHolder(zip, mem));
    }
}
