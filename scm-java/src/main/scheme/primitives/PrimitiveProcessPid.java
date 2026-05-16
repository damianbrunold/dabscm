package scheme.primitives;
import scheme.*;

public class PrimitiveProcessPid extends Primitive {
    @Override
    public String name() { return "process-pid"; }

    @Override
    public String info() {
        return "Syntax: (process-pid handle)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the OS process id of a process handle returned by " +
               "start-program.\n" +
               "Example:\n" +
               "  (process-pid p) => 12345";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeProcess sp = (SchemeProcess) Value.asNativeValue(arguments[0]).value;
        return sp.process.pid();
    }
}
