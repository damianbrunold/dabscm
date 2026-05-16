package scheme.primitives;

import scheme.*;

public class PrimitiveSpecialFolderTemp extends Primitive {
    @Override public String name() { return "special-folder-temp"; }
    @Override public String info() {
        return "Syntax: (special-folder-temp)\n" +
               "Library: (scm fs)\n" +
               "Description: Returns the platform temp directory path as a string.\n" +
               "Example: (special-folder-temp) => \"/tmp\"";
    }
    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return trimTrailingSeparator(System.getProperty("java.io.tmpdir")).toCharArray();
    }

    private static String trimTrailingSeparator(String path) {
        if (path == null || path.length() <= 1) return path;
        char last = path.charAt(path.length() - 1);
        if (last == '/' || last == '\\') {
            String trimmed = path.substring(0, path.length() - 1);
            if (trimmed.endsWith(":")) return path;
            return trimmed;
        }
        return path;
    }
}
