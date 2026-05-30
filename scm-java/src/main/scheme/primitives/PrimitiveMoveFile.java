package scheme.primitives;

import java.nio.file.Files;
import java.nio.file.StandardCopyOption;

import scheme.*;

public class PrimitiveMoveFile extends Primitive {
    @Override
    public String name() {
        return "move-file";
    }

    @Override
    public String info() {
        return "Syntax: (move-file src dest)\n" +
               "Library: (scm fs)\n" +
               "Description: Moves (renames) the file from src to dest, overwriting dest if it exists. Returns unspecified on success, #f on failure.\n" +
               "Example:\n" +
               "  (move-file \"old.txt\" \"new.txt\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        var src = new String(Value.asString(arguments[0]));
        var dst = new String(Value.asString(arguments[1]));
        try {
            Files.move(LongPath.of(src), LongPath.of(dst), StandardCopyOption.REPLACE_EXISTING);
            return new Values();
        } catch (Exception e) {
            return Value.F;
        }
    }
}
