package scheme.primitives;

import java.io.File;

import scheme.*;

public class PrimitiveFileExists extends Primitive {
    @Override
    public String name() {
        return "file-exists?";
    }

    @Override
    public String info() {
        return "Syntax: (file-exists? filename)\n" +
               "Library: (scheme file)\n" +
               "Description: Returns #t if the named file exists, otherwise returns #f.\n" +
               "Example:\n" +
               "  (file-exists? \"/etc/hosts\") => #t\n" +
               "  (file-exists? \"/nonexistent\") => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var path = new File(new String(Value.asString(arguments[0])));
        return path.isFile();
    }
}
