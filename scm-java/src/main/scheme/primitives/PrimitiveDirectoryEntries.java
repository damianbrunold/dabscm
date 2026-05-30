package scheme.primitives;

import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;

import scheme.*;

public class PrimitiveDirectoryEntries extends Primitive {
    @Override
    public String name() {
        return "directory-entries";
    }

    @Override
    public String info() {
        return "Syntax: (directory-entries dirname)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns a list of (name . type) pairs for the entries in dirname, where name is the entry name (not a full path) and type is one of the symbols file, directory, or symlink. Symlinks are reported as symlink regardless of what they point to (they are not followed).\n" +
               "Example:\n" +
               "  (directory-entries \"/tmp\") => ((\"a.txt\" . file) (\"sub\" . directory) (\"link\" . symlink) ...)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var dir = new String(Value.asString(arguments[0]));
        Object result = Value.NIL;
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(LongPath.of(dir))) {
            // Collect first so we can preserve directory order in the list.
            java.util.ArrayList<Path> entries = new java.util.ArrayList<>();
            for (Path p : stream) entries.add(p);
            for (int i = entries.size() - 1; i >= 0; i--) {
                Path p = entries.get(i);
                String type;
                if (Files.isSymbolicLink(p)) type = "symlink";
                else if (Files.isDirectory(p)) type = "directory";
                else type = "file";
                String entryName = p.getFileName().toString();
                result = new Pair(new Pair(entryName.toCharArray(), Value.intern(type)), result);
            }
            return result;
        } catch (Exception e) {
            return result;
        }
    }
}
