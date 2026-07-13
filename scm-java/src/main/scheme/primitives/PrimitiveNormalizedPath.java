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
               "Library: (scm fs)\n" +
               "Description: Returns the normalized form of path. If absolute, returns the full path; if relative, returns the relative path from the current directory.\n" +
               "Example:\n" +
               "  (normalized-path \"./foo/../bar\") => \"bar\"";
    }

    // For a relative input, return its path relative to the working
    // directory (e.g. "./foo/../bar" => "bar", "." => "."), matching the
    // C# build's Path.GetRelativePath. A plain substring of the workdir
    // prefix is wrong: it leaves a leading separator ("/bar") and yields
    // "" when the path canonicalises to the workdir itself.
    private static String relativeTo(File workdir, File path) {
        var rel = workdir.toPath().relativize(path.toPath()).toString();
        return rel.isEmpty() ? "." : rel;
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
                return relativeTo(workdir.getCanonicalFile(),
                                  path.getCanonicalFile()).toCharArray();
            }
        } catch (Exception e) {
            if (path.isAbsolute()) {
                return path.getAbsolutePath().toCharArray();
            } else {
                return relativeTo(workdir.getAbsoluteFile(),
                                  path.getAbsoluteFile()).toCharArray();
            }
        }
    }
}
