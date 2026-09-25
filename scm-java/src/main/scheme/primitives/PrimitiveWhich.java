package scheme.primitives;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

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
               "Description: Searches the directories in PATH for an executable named program and returns its full path as a string, or #f if not found. On Windows, a program name without an extension is tried with each PATHEXT extension (e.g. \"psql\" finds psql.exe).\n" +
               "Example:\n" +
               "  (which \"ls\") => \"/usr/bin/ls\"\n" +
               "  (which \"nonexistent\") => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var name = new String(Value.asString(arguments[0]));
        var candidates = candidates(name);
        var values = System.getenv("PATH");
        if (values == null) return Value.F;
        for (var path : values.split(File.pathSeparator)) {
            if (path.isEmpty()) continue;
            for (var candidate : candidates) {
                var fullPath = new File(path, candidate);
                if (fullPath.isFile()) {
                    return fullPath.toString().toCharArray();
                }
            }
        }
        return Value.F;
    }

    // On Windows a name without an extension is resolved like cmd.exe does:
    // by trying each PATHEXT extension in order (so "psql" finds psql.exe).
    private static List<String> candidates(String name) {
        var result = new ArrayList<String>();
        int slash = Math.max(name.lastIndexOf('\\'), name.lastIndexOf('/'));
        boolean hasExtension = name.lastIndexOf('.') > slash;
        if (!ProcessUtil.isWindows() || hasExtension) {
            result.add(name);
            return result;
        }
        var pathext = System.getenv("PATHEXT");
        if (pathext == null || pathext.isEmpty()) pathext = ".COM;.EXE;.BAT;.CMD";
        for (var ext : pathext.split(";")) {
            var e = ext.trim();
            if (!e.isEmpty()) result.add(name + e);
        }
        return result;
    }
}
