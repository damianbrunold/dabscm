package scheme.primitives;

import scheme.*;

import java.io.File;

public class PrimitiveBaseName extends Primitive
{
    @Override
    public String name() {
        return "base-name";
    }

    @Override
    public String info() {
        return "Syntax: (base-name path)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns the file name (including extension) from the given path string, without the directory part.\n" +
               "Example:\n" +
               "  (base-name \"/usr/share/doc/readme.txt\") => \"readme.txt\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var path = new String(Value.asString(arguments[0]));
        return new File(path).getName().toCharArray();
    }
}
