package scheme.primitives;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;

import scheme.Primitive;
import scheme.SourcePos;
import scheme.Value;
import scheme.Values;

public class PrimitiveCopyDirectory extends Primitive {
    @Override
    public String name() {
        return "copy-directory";
    }

    @Override
    public String info() {
        return "Syntax: (copy-directory src dest)\n" +
               "Library: (scm system)\n" +
               "Description: Recursively copies the directory at src to dest. Returns unspecified on success, #f on failure.\n" +
               "Example:\n" +
               "  (copy-directory \"/src/dir\" \"/dst/dir\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        var src = new File(new String(Value.asString(arguments[0])));
        var dst = new File(new String(Value.asString(arguments[1])));
        try {
            copyDirectory(src, dst);
            return new Values();
        } catch (Exception e) {
            return Value.F;
        }
    }

    static void copyDirectory(File src, File dest) throws IOException {
        if (src.exists() && src.isDirectory()) {
            if (!dest.exists()) dest.mkdir();
            File[] files = src.listFiles();
            for (File file : files) {
                if (file.isDirectory()) {
                    continue;
                }
                Files.copy(file.toPath(),
                        new File(dest, file.getName()).toPath(),
                        StandardCopyOption.REPLACE_EXISTING);
            }
            for (File file : files) {
                if (!file.isDirectory()) {
                    continue;
                }
                copyDirectory(file, new File(dest, file.getName()));
            }
        }
    }
}
