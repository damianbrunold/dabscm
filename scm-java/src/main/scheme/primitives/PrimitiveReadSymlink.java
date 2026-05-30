package scheme.primitives;

import java.nio.file.Files;
import java.nio.file.Path;

import scheme.*;

public class PrimitiveReadSymlink extends Primitive {
    @Override
    public String name() {
        return "read-symlink";
    }

    @Override
    public String info() {
        return "Syntax: (read-symlink path)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns the raw target string stored in the symbolic link at path, exactly as recorded (not resolved or canonicalized). Returns #f if path is not a symbolic link or cannot be read.\n" +
               "Example:\n" +
               "  (read-symlink \"/usr/local/bin/python\") => \"../bin/python3\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var path = new String(Value.asString(arguments[0]));
        try {
            Path target = Files.readSymbolicLink(LongPath.of(path));
            return LongPath.strip(target.toString()).toCharArray();
        } catch (Exception e) {
            return Value.F;
        }
    }
}
