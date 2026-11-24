
package scheme.primitives;

import java.io.File;
import java.lang.ProcessBuilder.Redirect;
import java.util.ArrayList;
import java.util.List;

import scheme.*;

public class PrimitiveRunProgram extends Primitive {
    @Override
    public String name() {
        return "run-program";
    }

    @Override
    public String info() {
        return "Syntax: (run-program cmd [options])\n" +
               "Library: (scm system)\n" +
               "Description: Executes the external program specified as a list (program arg1 arg2 ...), waits for it to complete, and returns its exit code as an exact integer. The program inherits the caller's standard input, output and error (so it can use the terminal; start-program gives it a private stdin instead). options is an alist with optional keys: 'work-dir <path>, 'env <alist of (name value) string pairs added to the child environment>, 'stdin <string> (the text the program reads), 'stdin-file <path>, 'stdout <path>, 'stderr <path> (the program writes to these files; output not redirected goes to the terminal as it is written), 'stderr 'stdout (stderr goes where stdout goes), 'append #t (the files are appended to). Returns #f on failure.\n" +
               "Example:\n" +
               "  (run-program '(\"echo\" \"hello\")) => 0";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        Pair cmdline = Value.asPair(arguments[0]);
        Object options = Value.NIL;
        if (arguments.length > 1) {
            options = arguments[1];
        }
        try {
            String cmd = new String(Value.asString(cmdline.car));
            List<String> cmd_args = new ArrayList<>();
            cmd_args.add(cmd);
            Object p = cmdline.cdr;
            while (p != Value.NIL) {
                var pp = Value.asPair(p);
                cmd_args.add(new String(Value.asString(pp.car)));
                p = pp.cdr;
            }

            var pb = new ProcessBuilder(ProcessUtil.resolveBatchLauncher(cmd_args));
            pb.directory(ProcessUtil.workDir(null));

            // The child runs in the foreground: it shares our stdin as well
            // (the JDK's default is a private pipe, so a child never saw the
            // terminal and e.g. a TUI started via run-program fell back to
            // plain output). start-program keeps the private pipe.
            pb.redirectInput(Redirect.INHERIT);
            pb.redirectOutput(Redirect.INHERIT);
            pb.redirectError(Redirect.INHERIT);
            String stdinText = null;
            if (options != Value.NIL) {
                // no 'work-dir -> inherit the current directory (a host "."
                // default isn't a Scheme string and made asString throw)
                Object val = PrimitiveGetProperty.getProperty(options, "work-dir", Value.F);
                if (val != Value.F) {
                    pb.directory(ProcessUtil.workDir(new String(Value.asString(val))));
                }
                ProcessUtil.applyEnv(pb, options);
                stdinText = ProcessUtil.applyRedirects(pb, options);
            }

            var process = pb.start();
            ProcessUtil.feedStdin(process, stdinText);
            return (long) process.waitFor();
        } catch (Exception e) {
            return Value.F;
        }
    }

}
