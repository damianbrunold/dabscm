package scheme.primitives;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.zip.CRC32;
import java.util.zip.ZipEntry;

import scheme.Primitive;
import scheme.SchemeError;
import scheme.SourcePos;
import scheme.Value;
import scheme.Values;
import scheme.ZipOutputHolder;

public class PrimitiveZipAddFileEntry extends Primitive {
    @Override
    public String name() { return "zip-add-file-entry"; }

    @Override
    public String info() {
        return "Syntax: (zip-add-file-entry zip name path [compress?])\n" +
               "Library: (scm zip)\n" +
               "Description: Adds the file at path to the ZIP archive zip as the entry named name, reading it in\n" +
               "  pieces, so the file may be larger than memory. The entry is stored uncompressed unless\n" +
               "  compress? is true: images, videos and other compressed formats gain nothing from deflating.\n" +
               "Example:\n" +
               "  (zip-add-file-entry zip \"assets/video.mp4\" \"/var/lib/app/video.mp4\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 3, 4);
        ZipOutputHolder holder = (ZipOutputHolder) Value.asNativeValue(arguments[0]).value;
        String entryName = new String(Value.asString(arguments[1]));
        Path path = Paths.get(new String(Value.asString(arguments[2])));
        boolean compress = arguments.length > 3 && arguments[3] != Value.F;
        try {
            ZipEntry ze = new ZipEntry(entryName);
            byte[] buf = new byte[65536];
            int n;
            if (compress) {
                ze.setMethod(ZipEntry.DEFLATED);
            } else {
                // STORED needs size and CRC up front: a first pass.
                CRC32 crc = new CRC32();
                long size = 0;
                try (InputStream in = Files.newInputStream(path)) {
                    while ((n = in.read(buf)) != -1) { crc.update(buf, 0, n); size += n; }
                }
                ze.setMethod(ZipEntry.STORED);
                ze.setSize(size);
                ze.setCompressedSize(size);
                ze.setCrc(crc.getValue());
            }
            ze.setTime(Files.getLastModifiedTime(path).toMillis());
            holder.zip.putNextEntry(ze);
            try (InputStream in = Files.newInputStream(path)) {
                while ((n = in.read(buf)) != -1) holder.zip.write(buf, 0, n);
            }
            holder.zip.closeEntry();
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": io failure: ~s", e.getMessage());
        }
    }
}
