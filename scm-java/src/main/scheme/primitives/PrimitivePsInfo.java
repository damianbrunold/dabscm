package scheme.primitives;
import scheme.*;

public class PrimitivePsInfo extends Primitive {
    @Override
    public String name() { return "ps-info"; }

    @Override
    public String info() {
        return "Syntax: (ps-info pid)\n" +
               "Library: (scm system)\n" +
               "Description: Returns an alist describing the process with the given pid,\n" +
               "  or #f if no such process exists or it cannot be inspected. See (ps)\n" +
               "  for the field set.\n" +
               "Example:\n" +
               "  (cdr (assq 'command (ps-info (current-pid)))) => \"scm\"";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        long pid = IntegerMath.toLong(arguments[0]);
        var h = ProcessHandle.of(pid);
        if (!h.isPresent()) return Value.F;
        return PrimitivePs.buildInfo(h.get());
    }
}
