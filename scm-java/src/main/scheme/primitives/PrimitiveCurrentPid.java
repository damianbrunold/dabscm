package scheme.primitives;
import scheme.*;

public class PrimitiveCurrentPid extends Primitive {
    @Override
    public String name() { return "current-pid"; }

    @Override
    public String info() {
        return "Syntax: (current-pid)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the OS process id of the current Scheme process.\n" +
               "Example:\n" +
               "  (current-pid) => 12345";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        return ProcessHandle.current().pid();
    }
}
