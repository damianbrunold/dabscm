package scheme.primitives;

import scheme.*;

import java.io.File;

public class PrimitiveAbsolutePath extends Primitive {
    @Override
    public String name() {
        return "absolute-path";
    }

    @Override
    public String info() {
        return "Syntax: (absolute-path path)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the absolute (fully qualified) form of the given path string.\n" +
               "Example:\n" +
               "  (absolute-path \".\") => \"/current/working/dir\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var path = new String(Value.asString(arguments[0]));
        return new File(path).getAbsolutePath().toCharArray();
    }
}
