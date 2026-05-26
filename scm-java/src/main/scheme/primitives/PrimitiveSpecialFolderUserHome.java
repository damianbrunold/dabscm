package scheme.primitives;

import java.io.File;

import scheme.*;

public class PrimitiveSpecialFolderUserHome extends Primitive {
    @Override
    public String name() {
        return "special-folder-user-home";
    }

    @Override
    public String info() {
        return "Syntax: (special-folder-user-home)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns the path of the user home directory as a string.\n" +
               "Example:\n" +
               "  (special-folder-user-home) => \"/home/user\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return System.getProperty("user.home").toCharArray();
    }
}
