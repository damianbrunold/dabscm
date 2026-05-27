package scheme.primitives;

import java.io.File;

import scheme.*;

public class PrimitiveWhich extends Primitive {
    @Override
    public String name() {
        return "which";
    }

    @Override
    public String info() {
        return "Syntax: (which program)\n" +
               "Library: (scm fs)\n" +
               "Description: Searches the directories in PATH for an executable named program and returns its full path as a string, or #f if not found.\n" +
               "Example:\n" +
               "  (which \"ls\") => \"/usr/bin/ls\"\n" +
               "  (which \"nonexistent\") => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var name = new String(Value.asString(arguments[0]));
        var values = System.getenv("PATH");
        for (var path : values.split(File.pathSeparator)) {
            var fullPath = new File(path, name);
            if (fullPath.exists()) {
                return fullPath.toString().toCharArray();
            }
        }
        return Value.F;
    }
}
