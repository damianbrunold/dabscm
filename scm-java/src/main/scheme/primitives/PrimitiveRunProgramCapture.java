package scheme.primitives;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import scheme.*;

public class PrimitiveRunProgramCapture extends Primitive {
    @Override
    public String name() { return "run-program/capture"; }

    @Override
    public String info() {
        return "Syntax: (run-program/capture cmd [options])\n" +
               "Library: (scm system)\n" +
               "Description: Executes the external program specified as a list " +
               "(program arg1 arg2 ...), waits for it to complete, and returns a list " +
               "(exit-code stdout stderr) where stdout and stderr are captured as strings. " +
               "options is an alist with optional keys: 'work-dir <path>, 'stdin <string> " +
               "(text to write to the child's standard input). Returns #f on failure.\n" +
               "Example:\n" +
               "  (run-program/capture '(\"echo\" \"hello\")) => (0 \"hello\\n\" \"\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        Pair cmdline = Value.asPair(arguments[0]);
        Object options = arguments.length > 1 ? arguments[1] : Value.NIL;

        try {
            String cmd = new String(Value.asString(cmdline.car));
            List<String> argv = new ArrayList<>();
            argv.add(cmd);
            Object p = cmdline.cdr;
            while (p != Value.NIL) {
                Pair pp = Value.asPair(p);
                argv.add(new String(Value.asString(pp.car)));
                p = pp.cdr;
            }

            ProcessBuilder pb = new ProcessBuilder(argv);
            String stdinText = null;
            if (options != Value.NIL) {
                Object workdirVal = PrimitiveGetProperty.getProperty(options, "work-dir", Value.F);
                if (workdirVal != Value.F) {
                    pb.directory(new File(new String(Value.asString(workdirVal))));
                }
                Object stdinVal = PrimitiveGetProperty.getProperty(options, "stdin", Value.F);
                if (stdinVal != Value.F) {
                    stdinText = new String(Value.asString(stdinVal));
                }
            }

            Process proc = pb.start();

            if (stdinText != null) {
                OutputStream os = proc.getOutputStream();
                os.write(stdinText.getBytes(StandardCharsets.UTF_8));
                os.close();
            } else {
                proc.getOutputStream().close();
            }

            StringBuilder stdoutBuf = new StringBuilder();
            StringBuilder stderrBuf = new StringBuilder();

            Thread tOut = new Thread(() -> drain(proc.getInputStream(), stdoutBuf));
            Thread tErr = new Thread(() -> drain(proc.getErrorStream(), stderrBuf));
            tOut.start();
            tErr.start();

            int exit = proc.waitFor();
            tOut.join();
            tErr.join();

            Object result = Value.NIL;
            result = new Pair(stderrBuf.toString().toCharArray(), result);
            result = new Pair(stdoutBuf.toString().toCharArray(), result);
            result = new Pair((long) exit, result);
            return result;
        } catch (Exception e) {
            return Value.F;
        }
    }

    private static void drain(java.io.InputStream is, StringBuilder buf) {
        try (BufferedReader r = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            char[] chunk = new char[4096];
            int n;
            while ((n = r.read(chunk)) >= 0) {
                buf.append(chunk, 0, n);
            }
        } catch (Exception ignored) {
        }
    }
}
