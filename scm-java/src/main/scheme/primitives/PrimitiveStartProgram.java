package scheme.primitives;
import scheme.*;
import java.io.File;
import java.util.ArrayList;
import java.util.List;

public class PrimitiveStartProgram extends Primitive {
    @Override
    public String name() { return "start-program"; }

    @Override
    public String info() {
        return "Syntax: (start-program cmd-and-args [options])\n" +
               "Library: (scm system)\n" +
               "Description: Starts an external program without waiting for it to finish " +
               "and returns a process handle (a native value). cmd-and-args is a list " +
               "(program arg1 arg2 ...). options is an alist with optional keys: " +
               "'work-dir <path>, 'log-file <path> (redirects stdout+stderr to this file), " +
               "'env <alist of (name value) string pairs added to the child environment>, " +
               "'stdin <string> (the text the program reads; else a private stdin with nothing to read), " +
               "'stdin-file <path>, 'stdout <path>, 'stderr <path>, 'stderr 'stdout (stderr goes where stdout goes), " +
               "'append #t (the files are appended to), 'new-group #t (the program runs in a process group of its own, " +
               "so that Ctrl+C at the terminal does not reach it; on Windows the program ignores Ctrl+C; " +
               "the JVM cannot do this on Windows). " +
               "Use process-pid, process-kill, process-wait, process-alive? on the handle.\n" +
               "Example:\n" +
               "  (define p (start-program '(\"sleep\" \"30\")))\n" +
               "  (process-kill p)\n" +
               "  (process-wait p)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        Pair cmdline = Value.asPair(arguments[0]);
        Object options = arguments.length > 1 ? arguments[1] : Value.NIL;

        String cmd = new String(Value.asString(cmdline.car));
        List<String> argv = new ArrayList<>();
        argv.add(cmd);
        Object p = cmdline.cdr;
        while (p != Value.NIL) {
            Pair pp = Value.asPair(p);
            argv.add(new String(Value.asString(pp.car)));
            p = pp.cdr;
        }

        try {
            List<String> command = ProcessUtil.resolveBatchLauncher(argv);
            if (options != Value.NIL
                && PrimitiveGetProperty.getProperty(options, "new-group", Value.F) != Value.F)
                command = ProcessUtil.newGroupCommand(command);
            ProcessBuilder pb = new ProcessBuilder(command);
            pb.directory(ProcessUtil.workDir(null));

            String stdinText = null;
            pb.redirectOutput(ProcessBuilder.Redirect.INHERIT);
            pb.redirectError(ProcessBuilder.Redirect.INHERIT);
            if (options != Value.NIL) {
                Object workdirVal = PrimitiveGetProperty.getProperty(options, "work-dir", Value.F);
                if (workdirVal != Value.F) {
                    pb.directory(ProcessUtil.workDir(new String(Value.asString(workdirVal))));
                }
                Object logfileVal = PrimitiveGetProperty.getProperty(options, "log-file", Value.F);
                if (logfileVal != Value.F) {
                    File lf = SchemePaths.file(new String(Value.asString(logfileVal)));
                    boolean append = PrimitiveGetProperty.getProperty(options, "append", Value.F) != Value.F;
                    pb.redirectOutput(append ? ProcessBuilder.Redirect.appendTo(lf) : ProcessBuilder.Redirect.to(lf));
                    pb.redirectErrorStream(true);
                }
                ProcessUtil.applyEnv(pb, options);
                stdinText = ProcessUtil.applyRedirects(pb, options);
            }

            Process proc = pb.start();
            ProcessUtil.feedStdin(proc, stdinText);
            return new NativeValue(new SchemeProcess(proc));
        } catch (Exception e) {
            throw new SchemeError(pos, "start-program: " + e.getMessage());
        }
    }
}
