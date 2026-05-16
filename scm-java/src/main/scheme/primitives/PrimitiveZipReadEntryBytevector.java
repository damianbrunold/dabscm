package scheme.primitives;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;

import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.ZipInputHolder;

public class PrimitiveZipReadEntryBytevector extends Primitive {
    @Override
    public String name() {
        return "zip-read-entry-bytevector";
    }

    @Override
    public String info() {
        return "Syntax: (zip-read-entry-bytevector zip name)\n" +
               "Library: (scm zip)\n" +
               "Description: Reads the contents of the entry named name from the ZIP archive zip and returns it as a bytevector.\n" +
               "Example:\n" +
               "  (zip-read-entry-bytevector z \"hello.txt\") => #u8(72 101 108 108 111)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        try {
            ZipInputHolder holder = (ZipInputHolder) Value.asNativeValue(arguments[0]).value;
            String entryName = new String(Value.asString(arguments[1]));
            var entry = holder.zip.getEntry(entryName);
            if (entry == null)
                throw new SchemeError(pos, name() + ": entry not found, ~s", entryName);
            try (InputStream in = holder.zip.getInputStream(entry)) {
                ByteArrayOutputStream buf = new ByteArrayOutputStream();
                byte[] tmp = new byte[8192];
                int n;
                while ((n = in.read(tmp)) != -1) buf.write(tmp, 0, n);
                return buf.toByteArray();
            }
        } catch (SchemeError e) {
            throw e;
        } catch (Exception e) {
            throw new SchemeError(pos, name() + " failed: ~s", e.getMessage());
        }
    }
}
