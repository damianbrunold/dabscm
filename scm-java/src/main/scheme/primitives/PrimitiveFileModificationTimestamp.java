package scheme.primitives;

import java.nio.file.Files;

import scheme.*;

public class PrimitiveFileModificationTimestamp extends Primitive {
    @Override
    public String name() {
        return "file-modification-timestamp";
    }

    @Override
    public String info() {
        return "Syntax: (file-modification-timestamp filename)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns the last modification time of the file as a millisecond timestamp (milliseconds since the Unix epoch, UTC).\n" +
               "Example:\n" +
               "  (file-modification-timestamp \"data.txt\") => 1700000000000";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var file = new String(Value.asString(arguments[0]));
        try {
            return Files.getLastModifiedTime(LongPath.of(file)).toMillis();
        } catch (Exception e) {
            return 0L;
        }
    }
}
