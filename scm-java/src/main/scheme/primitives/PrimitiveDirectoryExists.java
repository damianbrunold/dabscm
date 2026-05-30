package scheme.primitives;

import java.nio.file.Files;

import scheme.*;

public class PrimitiveDirectoryExists extends Primitive {
    @Override
    public String name() {
        return "directory-exists?";
    }

    @Override
    public String info() {
        return "Syntax: (directory-exists? dirname)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns #t if the given path names an existing directory, otherwise returns #f.\n" +
               "Example:\n" +
               "  (directory-exists? \"/tmp\") => #t\n" +
               "  (directory-exists? \"/nonexistent\") => #f";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var dir = new String(Value.asString(arguments[0]));
        return Files.isDirectory(LongPath.of(dir)) ? Value.T : Value.F;
    }
}
