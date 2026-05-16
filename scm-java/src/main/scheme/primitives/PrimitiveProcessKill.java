package scheme.primitives;
import scheme.*;

public class PrimitiveProcessKill extends Primitive {
    @Override
    public String name() { return "process-kill"; }

    @Override
    public String info() {
        return "Syntax: (process-kill handle [force?])\n" +
               "Library: (scm system)\n" +
               "Description: Stops a process started by start-program. With force? = #f " +
               "(default) requests a normal termination (SIGTERM on Unix, TerminateProcess " +
               "on Windows via Process.destroy). With force? = #t kills forcefully " +
               "(SIGKILL on Unix). Returns #t.\n" +
               "Example:\n" +
               "  (process-kill p)        ; graceful where supported\n" +
               "  (process-kill p #t)     ; force";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        SchemeProcess sp = (SchemeProcess) Value.asNativeValue(arguments[0]).value;
        boolean force = arguments.length > 1 && arguments[1] != Value.F;
        if (!sp.process.isAlive()) return Value.T;
        try {
            if (force) sp.process.destroyForcibly();
            else       sp.process.destroy();
        } catch (Exception ignored) {}
        return Value.T;
    }
}
