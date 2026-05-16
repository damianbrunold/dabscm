package scheme.primitives;
import scheme.*;

public class PrimitiveProcessAliveQ extends Primitive {
    @Override
    public String name() { return "process-alive?"; }

    @Override
    public String info() {
        return "Syntax: (process-alive? handle)\n" +
               "Library: (scm system)\n" +
               "Description: Returns #t if the process started by start-program is still " +
               "running, #f if it has exited.\n" +
               "Example:\n" +
               "  (process-alive? p) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        SchemeProcess sp = (SchemeProcess) Value.asNativeValue(arguments[0]).value;
        return sp.process.isAlive() ? Value.T : Value.F;
    }
}
