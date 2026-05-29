package scheme.primitives;
import scheme.*;

public class PrimitiveKill extends Primitive {
    @Override
    public String name() { return "kill"; }

    @Override
    public String info() {
        return "Syntax: (kill pid [force?])\n" +
               "Library: (scm system)\n" +
               "Description: Sends a termination request to the process with the given\n" +
               "  pid. With force? = #f (default) requests a normal termination\n" +
               "  (SIGTERM on Unix); with force? = #t kills forcefully (SIGKILL on Unix).\n" +
               "  Returns #t if the request was delivered, #f if the process does not\n" +
               "  exist or the caller lacks permission to signal it.\n" +
               "Example:\n" +
               "  (kill 12345)        ; graceful\n" +
               "  (kill 12345 #t)     ; force";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        long pid = IntegerMath.toLong(arguments[0]);
        boolean force = arguments.length > 1 && arguments[1] != Value.F;
        var h = ProcessHandle.of(pid);
        if (!h.isPresent()) return Value.F;
        try {
            boolean ok = force ? h.get().destroyForcibly() : h.get().destroy();
            return ok ? Value.T : Value.F;
        } catch (Exception e) {
            return Value.F;
        }
    }
}
