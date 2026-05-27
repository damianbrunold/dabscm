package scheme.primitives;

import scheme.*;

public class PrimitiveSetCurrentDirectory extends Primitive {
    @Override
    public String name() { return "set-current-directory!"; }

    @Override
    public String info() {
        return "Syntax: (set-current-directory! path)\n" +
               "Library: (scm core)\n" +
               "Description: Sets the process working directory hint to path. Returns " +
               "the new directory as a string on success, #f on failure. Note: in the " +
               "JVM the OS-level cwd cannot be changed for already-loaded native code; " +
               "the value is recorded so that subsequent relative-path operations and " +
               "child-process invocations behave as if cwd were path.\n" +
               "Example:\n" +
               "  (set-current-directory! \"/tmp\") => \"/tmp\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            String path = new String(Value.asString(arguments[0]));
            java.io.File f = new java.io.File(path);
            if (!f.isDirectory()) return Value.F;
            System.setProperty("user.dir", f.getAbsolutePath());
            return f.getAbsolutePath().toCharArray();
        } catch (Exception e) {
            return Value.F;
        }
    }
}
