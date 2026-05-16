package scheme.primitives;

import java.io.OutputStreamWriter;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import scheme.Encoding;
import scheme.IntegerMath;
import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.ZipOutputHolder;

public class PrimitiveZipAddTextEntry extends Primitive {
    @Override
    public String name() {
        return "zip-add-text-entry";
    }

    @Override
    public String info() {
        return "Syntax: (zip-add-text-entry zip name [timestamp])\n" +
               "Library: (scm zip)\n" +
               "Description: Creates a new text entry named name in the ZIP archive zip and\n" +
               "  returns a UTF-8 textual output port for writing to it. The optional timestamp\n" +
               "  is a Unix epoch in seconds.\n" +
               "Example:\n" +
               "  (let ((port (zip-add-text-entry zip \"readme.txt\"))) (display \"Hello\" port))";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 3);
        try {
            ZipOutputHolder holder = (ZipOutputHolder) Value.asNativeValue(arguments[0]).value;
            String entryname = new String(Value.asString(arguments[1]));
            ZipEntry ze = new ZipEntry(entryname);
            if (arguments.length > 2)
                ze.setTime(IntegerMath.toLong(arguments[2]) * 1000L);
            holder.zip.putNextEntry(ze);
            return new OutputStreamWriter(holder.zip, Encoding.getEncoding("utf8"));
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~s", e.getMessage());
        }
    }
}
