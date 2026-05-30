package scheme.primitives;

import scheme.*;

import java.nio.file.Files;

import static java.nio.file.StandardCopyOption.*;

public class PrimitiveCopyFile extends Primitive {
    @Override
    public String name() {
        return "copy-file";
    }

    @Override
    public String info() {
        return "Syntax: (copy-file src dest)\n" +
               "Library: (scm fs)\n" +
               "Description: Copies the file at src to dest, overwriting dest if it exists. Returns unspecified on success, #f on failure.\n" +
               "Example:\n" +
               "  (copy-file \"data.txt\" \"backup.txt\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        var src = new String(Value.asString(arguments[0]));
        var dst = new String(Value.asString(arguments[1]));
        try {
            Files.copy(
                LongPath.of(src),
                LongPath.of(dst),
                REPLACE_EXISTING,
                COPY_ATTRIBUTES
            );
            return new Values();
        } catch (Exception e) {
            return Value.F;
        }
    }
}
