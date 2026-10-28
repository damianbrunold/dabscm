package scheme.primitives;

import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.ZipInputHolder;

public class PrimitiveZipEntrySize extends Primitive {
    @Override
    public String name() { return "zip-entry-size"; }

    @Override
    public String info() {
        return "Syntax: (zip-entry-size zip name)\n" +
               "Library: (scm zip)\n" +
               "Description: Returns the uncompressed size in bytes the archive declares for the entry named\n" +
               "  name, or #f if it declares none. Check it before reading an entry of an archive you did not\n" +
               "  make (a small archive can unpack to gigabytes); zip-extract-entry also enforces a limit.\n" +
               "Example:\n" +
               "  (zip-entry-size z \"hello.txt\") => 5";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        ZipInputHolder holder = (ZipInputHolder) Value.asNativeValue(arguments[0]).value;
        String entryName = new String(Value.asString(arguments[1]));
        var entry = holder.zip.getEntry(entryName);
        if (entry == null)
            throw new SchemeError(pos, name() + ": entry not found, ~s", entryName);
        long size = entry.getSize();
        return size < 0 ? Value.F : (Object) size;
    }
}
