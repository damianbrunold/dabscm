package scheme.primitives;

import java.nio.file.Files;
import java.nio.file.Paths;

import scheme.*;

public class PrimitiveMakeSymlink extends Primitive {
    @Override
    public String name() {
        return "make-symlink";
    }

    @Override
    public String info() {
        return "Syntax: (make-symlink target linkpath)\n" +
               "Library: (scm fs)\n" +
               "Description: Creates a symbolic link at linkpath whose target is the string target, stored verbatim (target need not exist). Does not replace an existing linkpath. Returns unspecified on success, #f on failure. On Windows, requires symlink-creation privilege (Developer Mode or elevation).\n" +
               "Example:\n" +
               "  (make-symlink \"../bin/python3\" \"/usr/local/bin/python\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        var target = new String(Value.asString(arguments[0]));
        var link = new String(Value.asString(arguments[1]));
        try {
            // The link location may be long; the target is stored verbatim.
            Files.createSymbolicLink(LongPath.of(link), Paths.get(target));
            return new Values();
        } catch (Exception e) {
            return Value.F;
        }
    }
}
