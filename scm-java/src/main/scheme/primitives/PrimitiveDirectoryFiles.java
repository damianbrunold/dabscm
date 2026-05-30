package scheme.primitives;

import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;

import scheme.*;

public class PrimitiveDirectoryFiles extends Primitive {
    @Override
    public String name() {
        return "directory-files";
    }

    @Override
    public String info() {
        return "Syntax: (directory-files dirname)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns a list of file names (not full paths) in the directory dirname.\n" +
               "Example:\n" +
               "  (directory-files \"/tmp\") => (\"file1.txt\" \"file2.txt\" ...)";
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
                if (Files.isDirectory(entries.get(i))) continue;
                result = new Pair(entries.get(i).getFileName().toString().toCharArray(), result);
            }
        } catch (Exception e) {
            // listFiles() returned null (and NPE'd) on a non-directory before;
            // return an empty list instead.
        }
        return result;
    }
}
