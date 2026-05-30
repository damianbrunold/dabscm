package scheme.primitives;

import java.nio.file.Files;
import java.nio.file.attribute.FileTime;

import scheme.*;

public class PrimitiveSetFileModificationTime extends Primitive {
    @Override
    public String name() {
        return "set-file-modification-time!";
    }

    @Override
    public String info() {
        return "Syntax: (set-file-modification-time! path millis)\n" +
               "Library: (scm fs)\n" +
               "Description: Sets the last-modification time of the file or directory at path to millis (milliseconds since the Unix epoch, UTC). Returns unspecified on success, #f on failure. The unit matches the value returned by file-modification-timestamp.\n" +
               "Example:\n" +
               "  (set-file-modification-time! \"dir\" (file-modification-timestamp \"src\"))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        var path = new String(Value.asString(arguments[0]));
        long millis = Value.asInteger(arguments[1]);
        try {
            Files.setLastModifiedTime(LongPath.of(path), FileTime.fromMillis(millis));
            return new Values();
        } catch (Exception e) {
            return Value.F;
        }
    }
}
