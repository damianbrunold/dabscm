package scheme.primitives;

import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;

import scheme.*;

public class PrimitiveDirectoryDirectories extends Primitive {
    @Override
    public String name() {
        return "directory-directories";
    }

    @Override
    public String info() {
        return "Syntax: (directory-directories dirname)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns a list of subdirectory names (not full paths) in the directory dirname.\n" +
               "Example:\n" +
               "  (directory-directories \"/usr\") => (\"bin\" \"lib\" \"share\" ...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var dir = new String(Value.asString(arguments[0]));
        Object result = Value.NIL;
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(LongPath.of(dir))) {
            ArrayList<Path> entries = new ArrayList<>();
            for (Path p : stream) entries.add(p);
            for (int i = entries.size() - 1; i >= 0; i--) {
                if (!Files.isDirectory(entries.get(i))) continue;
                result = new Pair(entries.get(i).getFileName().toString().toCharArray(), result);
            }
        } catch (Exception e) {
            // null/NPE on non-directory before; return empty list instead.
        }
        return result;
    }
}
