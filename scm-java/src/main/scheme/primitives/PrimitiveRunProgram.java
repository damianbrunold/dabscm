
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
        return "Syntax: (run-program cmd)\n" +
               "Library: (scm system)\n" +
               "Description: Executes the external program specified as a list (program arg1 arg2 ...), waits for it to complete, and returns its exit code as an exact integer. Returns #f on failure.\n" +
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

            if (options != Value.NIL) {
                var val = PrimitiveGetProperty.getProperty(
                    options,
                    "work-dir",
                    "."
                );
                var workdir = new File(new String(Value.asString(val))).getAbsoluteFile();
                pb.directory(workdir);
            }

            pb.redirectOutput(Redirect.INHERIT);
            pb.redirectError(Redirect.INHERIT);
            var process = pb.start();
            return (long) process.waitFor();
        } catch (Exception e) {
            return Value.F;
        }
    }

}
