package scheme.primitives;

import java.io.IOException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;

import scheme.Primitive;
import scheme.SourcePos;
import scheme.Value;
import scheme.Values;
import scheme.LongPath;

public class PrimitiveCopyDirectory extends Primitive {
    @Override
    public String name() {
        return "copy-directory";
    }

    @Override
    public String info() {
        return "Syntax: (copy-directory src dest)\n" +
               "Library: (scm fs)\n" +
               "Description: Recursively copies the directory at src to dest. Returns unspecified on success, #f on failure.\n" +
               "Example:\n" +
               "  (copy-directory \"/src/dir\" \"/dst/dir\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        var src = LongPath.of(new String(Value.asString(arguments[0])));
        var dst = LongPath.of(new String(Value.asString(arguments[1])));
        try {
            copyDirectory(src, dst);
            return new Values();
        } catch (Exception e) {
            return Value.F;
        }
    }

    static void copyDirectory(Path src, Path dest) throws IOException {
        if (!Files.isDirectory(src)) return;
        if (!Files.exists(dest)) Files.createDirectories(dest);
        ArrayList<Path> entries = new ArrayList<>();
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(src)) {
            for (Path p : stream) entries.add(p);
        }
        for (Path p : entries) {
            if (Files.isDirectory(p)) continue;
            Files.copy(p, dest.resolve(p.getFileName().toString()),
                       StandardCopyOption.REPLACE_EXISTING);
        }
        for (Path p : entries) {
            if (!Files.isDirectory(p)) continue;
            copyDirectory(p, dest.resolve(p.getFileName().toString()));
        }
    }
}
