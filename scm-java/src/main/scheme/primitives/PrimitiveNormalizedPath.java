package scheme.primitives;

import java.io.File;

import scheme.Primitive;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveNormalizedPath extends Primitive {
    @Override
    public String name() {
        return "normalized-path";
    }

    @Override
    public String info() {
        return "Syntax: (normalized-path path)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the normalized form of path. If absolute, returns the full path; if relative, returns the relative path from the current directory.\n" +
               "Example:\n" +
               "  (normalized-path \"./foo/../bar\") => \"bar\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var workdir = new File(System.getProperty("user.dir"));
        var path = new File(new String(Value.asString(arguments[0])));
        try {
            if (path.isAbsolute()) {
                return path.getCanonicalPath().toCharArray();
            } else {
                return path.getCanonicalPath().substring(workdir.getCanonicalPath().length()).toCharArray();
            }
        } catch (Exception e) {
            if (path.isAbsolute()) {
                return path.getAbsolutePath().toCharArray();
            } else {
                return path.getAbsolutePath().substring(workdir.getAbsolutePath().length());
            }
        }
    }
}
