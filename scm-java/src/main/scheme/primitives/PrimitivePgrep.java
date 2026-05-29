package scheme.primitives;
import scheme.*;

public class PrimitivePgrep extends Primitive {
    @Override
    public String name() { return "pgrep"; }

    @Override
    public String info() {
        return "Syntax: (pgrep pattern [full?])\n" +
               "Library: (scm system)\n" +
               "Description: Returns a list of pids whose command matches the substring\n" +
               "  pattern. By default matches against the process name. If full? is #t,\n" +
               "  matches against the full command line (where the platform supplies it).\n" +
               "  Pattern matching is case-sensitive substring.\n" +
               "Example:\n" +
               "  (pgrep \"java\") => (1234 5678)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        String pattern = new String(Value.asString(arguments[0]));
        boolean full = arguments.length > 1 && arguments[1] != Value.F;
        Object list = Value.NIL;
        var iter = ProcessHandle.allProcesses().iterator();
        while (iter.hasNext()) {
            var h = iter.next();
            var info = h.info();
            String hay = null;
            if (full && info.commandLine().isPresent()) {
                hay = info.commandLine().get();
            } else if (info.command().isPresent()) {
                hay = info.command().get();
            }
            if (hay != null && hay.contains(pattern)) {
                list = new Pair(h.pid(), list);
            }
        }
        return list;
    }
}
