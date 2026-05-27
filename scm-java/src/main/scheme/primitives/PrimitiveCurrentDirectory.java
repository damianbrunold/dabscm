package scheme.primitives;

import scheme.*;

public class PrimitiveCurrentDirectory extends Primitive {
    @Override
    public String name() {
        return "current-directory";
    }

    @Override
    public String info() {
        return "Syntax: (current-directory)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns the current working directory as a string.\n" +
               "Example:\n" +
               "  (current-directory) => \"/home/user/projects\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return System.getProperty("user.dir").toCharArray();
    }
}
