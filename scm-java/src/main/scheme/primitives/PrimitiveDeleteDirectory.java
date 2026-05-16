package scheme.primitives;

import scheme.*;

import java.io.File;
import java.nio.file.Files;
import java.util.Comparator;

public class PrimitiveDeleteDirectory extends Primitive {
    @Override
    public String name() {
        return "delete-directory";
    }

    @Override
    public String info() {
        return "Syntax: (delete-directory dir)\n" +
               "Library: (scm system)\n" +
               "Description: Recursively deletes the directory at dir. Returns unspecified on success, #f on failure.\n" +
               "Example:\n" +
               "  (delete-directory \"/tmp/old-dir\")";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var dir = new File(new String(Value.asString(arguments[0])));
        try {
            Files.walk(dir.toPath())
                 .sorted(Comparator.reverseOrder())
                 .map(java.nio.file.Path::toFile)
                 .forEach(File::delete);
            return new Values();
        } catch (Exception e) {
            return Value.F;
        }
    }
}
