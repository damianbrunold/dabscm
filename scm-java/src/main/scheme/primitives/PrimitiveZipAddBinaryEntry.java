package scheme.primitives;

import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import scheme.BinaryOutputStream;
import scheme.IntegerMath;
import scheme.NativeValue;
import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.ZipOutputHolder;

public class PrimitiveZipAddBinaryEntry extends Primitive {
    @Override
    public String name() {
        return "zip-add-binary-entry";
    }

    @Override
    public String info() {
        return "Syntax: (zip-add-binary-entry zip name [timestamp])\n" +
               "Library: (scm zip)\n" +
               "Description: Creates a new binary entry named name in the ZIP archive zip and\n" +
               "  returns an output binary port for writing to it. The optional timestamp is a\n" +
               "  Unix epoch in seconds.\n" +
               "Example:\n" +
               "  (let ((port (zip-add-binary-entry zip \"data.bin\"))) (write-bytevector bv port))";
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
            return new BinaryOutputStream(holder.zip, false);
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~s", e.getMessage());
        }
    }
}
