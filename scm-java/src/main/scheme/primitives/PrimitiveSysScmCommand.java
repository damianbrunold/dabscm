package scheme.primitives;

import java.io.File;
import java.lang.management.ManagementFactory;
import java.util.ArrayList;
import java.util.List;

import scheme.*;

public class PrimitiveSysScmCommand extends Primitive {
    @Override public String name() { return "sys-scm-command"; }

    @Override public String info() {
        return "Syntax: (sys-scm-command)\n" +
               "Library: (scm system)\n" +
               "Description: Returns the command line (a list of strings) that starts the currently running SCM interpreter. Append a script path and its arguments to run it with the same implementation (java or csharp) and installation, independent of what scm is on PATH.\n" +
               "Example:\n" +
               "  (sys-scm-command) => (\"/usr/lib/jvm/java-21/bin/java\" \"-jar\" \"/opt/dabscm/scm.jar\")\n" +
               "  (run-program (append (sys-scm-command) (list \"build.scm\")))";
    }

    @Override public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        List<String> cmd = new ArrayList<>();
        cmd.add(javaExecutable());
        // carry over JVM options (e.g. -Xss), but not debugger/agent attachments
        for (String opt : ManagementFactory.getRuntimeMXBean().getInputArguments()) {
            if (opt.startsWith("-agentlib") || opt.startsWith("-agentpath")
                || opt.startsWith("-javaagent") || opt.startsWith("-Xrunjdwp")
                || opt.equals("-Xdebug")) continue;
            cmd.add(opt);
        }
        String cp = System.getProperty("java.class.path");
        if (cp.endsWith(".jar") && !cp.contains(File.pathSeparator)) {
            cmd.add("-jar");
            cmd.add(new File(cp).getAbsolutePath());
        } else {
            cmd.add("-cp");
            cmd.add(cp);
            cmd.add(Scheme.class.getName());
        }
        Object[] items = new Object[cmd.size()];
        for (int i = 0; i < items.length; i++) items[i] = cmd.get(i).toCharArray();
        return Pair.list(items);
    }

    private static String javaExecutable() {
        String exe = ProcessHandle.current().info().command().orElse(null);
        if (exe != null) return exe;
        String name = System.getProperty("os.name").toLowerCase().contains("windows")
            ? "java.exe" : "java";
        return new File(new File(System.getProperty("java.home"), "bin"), name).getPath();
    }
}
