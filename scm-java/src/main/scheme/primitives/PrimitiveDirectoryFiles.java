package scheme.primitives;

import java.io.File;

import scheme.*;

public class PrimitiveDirectoryFiles extends Primitive {
    @Override
    public String name() {
        return "directory-files";
    }

    @Override
    public String info() {
        return "Syntax: (directory-files dirname)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns a list of file names (not full paths) in the directory dirname.\n" +
               "Example:\n" +
               "  (directory-files \"/tmp\") => (\"file1.txt\" \"file2.txt\" ...)";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        File dir = new File(new String(Value.asString(arguments[0])));
        File[] files = dir.listFiles();
        Object result = Value.NIL;
        for (int i = files.length - 1; i >= 0; i--) {
            if (files[i].isDirectory()) continue;
            result = new Pair(files[i].getName().toCharArray(), result);
        }
        return result;
    }
}
