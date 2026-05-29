package scheme.primitives;

import java.time.Instant;
import java.time.Duration;
import java.util.Optional;
import scheme.*;

public class PrimitivePs extends Primitive {
    @Override
    public String name() { return "ps"; }

    @Override
    public String info() {
        return "Syntax: (ps)\n" +
               "Library: (scm system)\n" +
               "Description: Returns a list of alists describing the processes currently\n" +
               "  visible on the system. Each alist has the keys:\n" +
               "    pid         — process id (integer)\n" +
               "    ppid        — parent pid (integer) or #f\n" +
               "    command     — process command as a string, or #f\n" +
               "    user        — owning user (string) or #f\n" +
               "    start-time  — epoch milliseconds (integer) or #f\n" +
               "    cpu-time    — accumulated cpu time in seconds (inexact) or #f\n" +
               "  Fields the platform cannot supply or that the current user cannot\n" +
               "  access are #f. Order is unspecified.\n" +
               "Example:\n" +
               "  (length (ps)) => 312";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        Object[] result = ProcessHandle.allProcesses()
            .map(PrimitivePs::buildInfo)
            .toArray();
        Object list = Value.NIL;
        for (Object item : result) list = new Pair(item, list);
        return list;
    }

    static Object buildInfo(ProcessHandle h) {
        long pid = h.pid();
        Object ppid = h.parent().map(p -> (Object) p.pid()).orElse(Value.F);
        ProcessHandle.Info info = h.info();
        Object command = info.command()
            .map(s -> (Object) s.toCharArray()).orElse(Value.F);
        // Prefer full command line where available.
        Optional<String> cmdline = info.commandLine();
        if (cmdline.isPresent()) command = cmdline.get().toCharArray();
        Object user = info.user()
            .map(s -> (Object) s.toCharArray()).orElse(Value.F);
        Object startTime = info.startInstant()
            .map(i -> (Object) i.toEpochMilli()).orElse(Value.F);
        Object cpuTime = info.totalCpuDuration()
            .map(d -> (Object) (d.toMillis() / 1000.0)).orElse(Value.F);
        return Pair.list(
            new Pair(Value.intern("pid"), pid),
            new Pair(Value.intern("ppid"), ppid),
            new Pair(Value.intern("command"), command),
            new Pair(Value.intern("user"), user),
            new Pair(Value.intern("start-time"), startTime),
            new Pair(Value.intern("cpu-time"), cpuTime));
    }
}
