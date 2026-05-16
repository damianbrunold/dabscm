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
               "'work-dir <path>, 'log-file <path> (redirects stdout+stderr to this file). " +
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
            ProcessBuilder pb = new ProcessBuilder(argv);

            boolean logfileSet = false;
            if (options != Value.NIL) {
                Object workdirVal = PrimitiveGetProperty.getProperty(options, "work-dir", Value.F);
                if (workdirVal != Value.F) {
                    pb.directory(new File(new String(Value.asString(workdirVal))));
                }
                Object logfileVal = PrimitiveGetProperty.getProperty(options, "log-file", Value.F);
                if (logfileVal != Value.F) {
                    File lf = new File(new String(Value.asString(logfileVal)));
                    pb.redirectOutput(ProcessBuilder.Redirect.to(lf));
                    pb.redirectErrorStream(true);
                    logfileSet = true;
                }
            }
            if (!logfileSet) {
                pb.redirectOutput(ProcessBuilder.Redirect.INHERIT);
                pb.redirectError(ProcessBuilder.Redirect.INHERIT);
            }

            Process proc = pb.start();
            return new NativeValue(new SchemeProcess(proc));
        } catch (Exception e) {
            throw new SchemeError(pos, "start-program: " + e.getMessage());
        }
    }
}
