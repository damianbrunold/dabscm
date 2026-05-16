package scheme.primitives;

import scheme.*;

import java.io.File;

public class PrimitiveMoveFile extends Primitive {
    @Override
    public String name() {
        return "move-file";
    }

    @Override
    public String info() {
        return "Syntax: (move-file src dest)\n" +
               "Library: (scm system)\n" +
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
            new File(src).renameTo(new File(dst));
            return new Values();
        } catch (Exception e) {
            return Value.F;
        }
    }
}
