package scheme.primitives;

import scheme.*;

public class PrimitiveSysUserName extends Primitive {
    @Override
    public String name() {
        return "sys-user-name";
    }

    @Override
    public String info() {
        return "Syntax: (sys-user-name)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the name of the currently logged-in user as a string.\n" +
               "Example:\n" +
               "  (sys-user-name) => \"alice\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return System.getProperty("user.name").toCharArray();
    }
}
