package scheme.primitives;

import java.util.zip.CRC32;
import java.util.zip.ZipEntry;

import scheme.IntegerMath;
import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.Values;
import scheme.ZipOutputHolder;

public class PrimitiveZipAddStoredEntry extends Primitive {
    @Override
    public String name() {
        return "zip-add-stored-entry";
    }

    @Override
    public String info() {
        return "Syntax: (zip-add-stored-entry zip name bytevector [timestamp])\n" +
               "Library: (scm zip)\n" +
               "Description: Creates a new uncompressed (STORED) entry named name in the\n" +
               "  ZIP archive zip and writes the entire bytevector as its content. Unlike\n" +
               "  zip-add-binary-entry, the data is stored without compression and must be\n" +
               "  provided in full. The optional timestamp is a Unix epoch in seconds.\n" +
               "  Returns void.\n" +
               "Example:\n" +
               "  (zip-add-stored-entry zip \"mimetype\" (string->utf8 \"application/xml\") 0)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 4);
        try {
            ZipOutputHolder holder = (ZipOutputHolder) Value.asNativeValue(arguments[0]).value;
            String entryname = new String(Value.asString(arguments[1]));
            byte[] data = Value.asBytevector(arguments[2]);
            ZipEntry ze = new ZipEntry(entryname);
            ze.setMethod(ZipEntry.STORED);
            ze.setSize(data.length);
            ze.setCompressedSize(data.length);
            CRC32 crc = new CRC32();
            crc.update(data);
            ze.setCrc(crc.getValue());
            if (arguments.length > 3)
                ze.setTime(IntegerMath.toLong(arguments[3]) * 1000L);
            holder.zip.putNextEntry(ze);
            holder.zip.write(data);
            holder.zip.closeEntry();
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~s", e.getMessage());
        }
    }
}
