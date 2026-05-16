package scheme.primitives;

import java.util.Collections;
import java.util.zip.ZipEntry;

import scheme.Pair;
import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.ZipInputHolder;

public class PrimitiveZipEntryNames extends Primitive {
    @Override
    public String name() {
        return "zip-entry-names";
    }

    @Override
    public String info() {
        return "Syntax: (zip-entry-names zip)\n" +
               "Library: (scm zip)\n" +
               "Description: Returns a list of entry name strings in the ZIP archive zip.\n" +
               "Example:\n" +
               "  (zip-entry-names z) => (\"file1.txt\" \"dir/file2.txt\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            ZipInputHolder holder = (ZipInputHolder) Value.asNativeValue(arguments[0]).value;
            var entries = Collections.list(holder.zip.entries());
            Object result = Value.NIL;
            for (int i = entries.size() - 1; i >= 0; i--) {
                result = new Pair(entries.get(i).getName().toCharArray(), result);
            }
            return result;
        } catch (Exception e) {
            throw new SchemeError(pos, name() + " failed: ~s", e.getMessage());
        }
    }
}
