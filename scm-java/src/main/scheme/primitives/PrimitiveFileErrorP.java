package scheme.primitives;
import scheme.*;

public class PrimitiveFileErrorP extends Primitive {
    @Override public String name() { return "file-error?"; }
    @Override public String info() {
        return "Syntax: (file-error? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is a file error object (as raised by file operations), otherwise returns #f.\n" +
               "Example:\n" +
               "  (guard (e (#t (file-error? e)))\n" +
               "    (open-input-file \"nonexistent\")) => #t";
    }
    @Override public Object apply(SourcePos pos, Object[] args) {
        checkArgs(pos, args, 1, 1);
        return args[0] instanceof FileErrorObject ? Value.T : Value.F;
    }
}
