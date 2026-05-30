package scheme.primitives;

import java.nio.file.Files;

import scheme.*;

public class PrimitiveFileModificationDate extends Primitive {
    @Override
    public String name() {
        return "file-modification-date";
    }

    @Override
    public String info() {
        return "Syntax: (file-modification-date filename)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns the last modification time of the file as seconds since the Unix epoch (UTC).\n" +
               "Example:\n" +
               "  (file-modification-date \"data.txt\") => 1700000000";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var file = new String(Value.asString(arguments[0]));
        try {
            return Files.getLastModifiedTime(LongPath.of(file)).toMillis() / 1000L;
        } catch (Exception e) {
            return 0L;
        }
    }
}
