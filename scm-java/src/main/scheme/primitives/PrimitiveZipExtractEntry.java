package scheme.primitives;

import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import scheme.IntegerMath;
import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.ZipInputHolder;

public class PrimitiveZipExtractEntry extends Primitive {
    @Override
    public String name() { return "zip-extract-entry"; }

    @Override
    public String info() {
        return "Syntax: (zip-extract-entry zip name path [max-bytes])\n" +
               "Library: (scm zip)\n" +
               "Description: Writes the contents of the entry named name to the file at path, in pieces, so the\n" +
               "  entry may be larger than memory, and returns the number of bytes written. With max-bytes, an\n" +
               "  entry that unpacks to more raises an error (whatever size the archive declares) and the\n" +
               "  partial file is deleted.\n" +
               "Example:\n" +
               "  (zip-extract-entry z \"video.mp4\" \"/tmp/video.mp4\" (* 1024 1024 1024)) => 52428800";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 4);
        ZipInputHolder holder = (ZipInputHolder) Value.asNativeValue(arguments[0]).value;
        String entryName = new String(Value.asString(arguments[1]));
        Path path = Paths.get(new String(Value.asString(arguments[2])));
        long max = arguments.length > 3 ? IntegerMath.toLong(arguments[3]) : Long.MAX_VALUE;
        var entry = holder.zip.getEntry(entryName);
        if (entry == null)
            throw new SchemeError(pos, name() + ": entry not found, ~s", entryName);
        long total = 0;
        boolean tooLarge = false;
        try (InputStream in = holder.zip.getInputStream(entry);
             OutputStream out = Files.newOutputStream(path)) {
            byte[] buf = new byte[65536];
            int n;
            while ((n = in.read(buf)) != -1) {
                total += n;
                if (total > max) { tooLarge = true; break; }
                out.write(buf, 0, n);
            }
        } catch (Exception e) {
            try { Files.deleteIfExists(path); } catch (Exception ignored) {}
            throw new SchemeError(pos, name() + " failed: ~s", e.getMessage());
        }
        if (tooLarge) {
            try { Files.deleteIfExists(path); } catch (Exception ignored) {}
            throw new SchemeError(pos, name() + ": entry ~s is larger than ~a bytes", entryName, max);
        }
        return total;
    }
}
