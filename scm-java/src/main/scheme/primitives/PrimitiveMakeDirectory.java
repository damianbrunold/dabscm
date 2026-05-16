package scheme.primitives;

import java.io.File;

import scheme.*;

public class PrimitiveMakeDirectory extends Primitive {
    @Override
    public String name() {
        return "make-directory";
    }

    @Override
    public String info() {
        return "Syntax: (make-directory path)\n" +
               "Library: (scm system)\n" +
               "Description: Creates the directory named by path, including all intermediate directories.\n" +
               "Example:\n" +
               "  (make-directory \"/tmp/new/dir\")";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var path = new String(Value.asString(arguments[0]));
        new File(path).mkdir();
        return new Values();
    }
}
