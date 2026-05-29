package scheme.primitives;
import scheme.*;

public class PrimitiveParentPid extends Primitive {
    @Override
    public String name() { return "parent-pid"; }

    @Override
    public String info() {
        return "Syntax: (parent-pid)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the OS process id of the parent of the current\n" +
               "  Scheme process, or #f if it cannot be determined.\n" +
               "Example:\n" +
               "  (parent-pid) => 12340";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        var parent = ProcessHandle.current().parent();
        if (parent.isPresent()) return parent.get().pid();
        return Value.F;
    }
}
