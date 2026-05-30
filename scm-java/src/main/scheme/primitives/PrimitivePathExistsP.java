package scheme.primitives;

import java.nio.file.Files;
import java.nio.file.LinkOption;

import scheme.*;

public class PrimitivePathExistsP extends Primitive {
    @Override
    public String name() {
        return "path-exists?";
    }

    @Override
    public String info() {
        return "Syntax: (path-exists? path)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns #t if path exists as a file, directory, or symbolic link (a dangling link still counts), without following links; otherwise #f. This is the lexists-style check.\n" +
               "Example:\n" +
               "  (path-exists? \"/etc/hosts\") => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var path = new String(Value.asString(arguments[0]));
        try {
            return Files.exists(LongPath.of(path), LinkOption.NOFOLLOW_LINKS) ? Value.T : Value.F;
        } catch (Exception e) {
            return Value.F;
        }
    }
}
