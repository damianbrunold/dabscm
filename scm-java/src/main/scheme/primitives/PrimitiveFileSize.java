package scheme.primitives;

import scheme.*;

import java.io.File;

public class PrimitiveFileSize extends Primitive {
    @Override
    public String name() {
        return "file-size";
    }

    @Override
    public String info() {
        return "Syntax: (file-size file)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the size of the named file in bytes as an exact integer, or #f if the file cannot be accessed.\n" +
               "Example:\n" +
               "  (file-size \"/etc/hosts\") => 221";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var file = new String(Value.asString(arguments[0]));
        try {
            return new File(file).length();
        } catch (Exception e) {
            return Value.F;
        }
    }
}
