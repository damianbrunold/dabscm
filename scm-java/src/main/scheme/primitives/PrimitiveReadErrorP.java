package scheme.primitives;
import scheme.*;

public class PrimitiveReadErrorP extends Primitive {
    @Override public String name() { return "read-error?"; }
    @Override public String info() {
        return "Syntax: (read-error? obj)\n" +
               "Library: (scheme base)\n" +
               "Description: Returns #t if obj is an object representing an error that occurred while reading, otherwise returns #f.\n" +
               "Example:\n" +
               "  (read-error? (guard (e (#t e)) (read (open-input-string \"(\")))) => #t";
    }
    @Override public Object apply(SourcePos pos, Object[] args) {
        checkArgs(pos, args, 1, 1);
        return args[0] instanceof ReadErrorObject ? Value.T : Value.F;
    }
}
