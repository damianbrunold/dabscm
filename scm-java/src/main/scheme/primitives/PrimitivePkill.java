package scheme.primitives;
import scheme.*;

public class PrimitivePkill extends Primitive {
    @Override
    public String name() { return "pkill"; }

    @Override
    public String info() {
        return "Syntax: (pkill pattern [force? [full?]])\n" +
               "Library: (scm system)\n" +
               "Description: Sends a termination request to every process whose command\n" +
               "  matches the substring pattern. By default matches against the process\n" +
               "  name; if full? is #t, matches against the full command line. With\n" +
               "  force? = #t kills forcefully (SIGKILL on Unix). Returns the number of\n" +
               "  processes that were successfully signaled. Does NOT match the current\n" +
               "  Scheme process.\n" +
               "Example:\n" +
               "  (pkill \"sleep\") => 2";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 3);
        String pattern = new String(Value.asString(arguments[0]));
        boolean force = arguments.length > 1 && arguments[1] != Value.F;
        boolean full = arguments.length > 2 && arguments[2] != Value.F;
        long self = ProcessHandle.current().pid();
        long count = 0;
        var iter = ProcessHandle.allProcesses().iterator();
        while (iter.hasNext()) {
            var h = iter.next();
            if (h.pid() == self) continue;
            var info = h.info();
            String hay = null;
            if (full && info.commandLine().isPresent()) {
                hay = info.commandLine().get();
            } else if (info.command().isPresent()) {
                hay = info.command().get();
            }
            if (hay == null || !hay.contains(pattern)) continue;
            try {
                boolean ok = force ? h.destroyForcibly() : h.destroy();
                if (ok) count++;
            } catch (Exception ignored) { }
        }
        return count;
    }
}
