package scheme.primitives;

import java.nio.file.Files;

import scheme.*;

public class PrimitiveFileSymlinkP extends Primitive {
    @Override
    public String name() {
        return "file-symlink?";
    }

    @Override
    public String info() {
        return "Syntax: (file-symlink? path)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns #t if path names a symbolic link itself (without following it), otherwise #f. Returns #t even for a dangling link whose target is missing, and #f if path does not exist.\n" +
               "Example:\n" +
               "  (file-symlink? \"/usr/local/bin/python\") => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var path = new String(Value.asString(arguments[0]));
        try {
            return Files.isSymbolicLink(LongPath.of(path)) ? Value.T : Value.F;
        } catch (Exception e) {
            return Value.F;
        }
    }
}
