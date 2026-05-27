package scheme.primitives;

import java.io.File;

import scheme.*;

public class PrimitiveDirectoryName extends Primitive {
    @Override
    public String name() {
        return "directory-name";
    }

    @Override
    public String info() {
        return "Syntax: (directory-name path)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns the directory part of the given path as an absolute path string, or #f if there is no parent directory.\n" +
               "Example:\n" +
               "  (directory-name \"/usr/share/readme.txt\") => \"/usr/share\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var path = new File(new String(Value.asString(arguments[0])));
        path = new File(path.getAbsolutePath());
        return path.getParent().toCharArray();
    }
}
