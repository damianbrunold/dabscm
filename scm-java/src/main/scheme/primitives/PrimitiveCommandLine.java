package scheme.primitives;

import scheme.Pair;
import scheme.Primitive;
import scheme.Scheme;
import scheme.SourcePos;
import scheme.Value;

public class PrimitiveCommandLine extends Primitive {
    @Override
    public String name() {
        return "command-line";
    }

    @Override
    public String info() {
        return "Syntax: (command-line)\n" +
               "Library: (scheme process-context)\n" +
               "Description: Returns the command line passed to the process as a list of strings. The first element is typically the program name.\n" +
               "Example:\n" +
               "  (command-line) => (\"prog\" \"arg1\" \"arg2\")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        String[] args = Scheme.commandLineArgs;
        Object result = Value.NIL;
        for (int i = args.length - 1; i >= 0; i--) {
            result = new Pair(args[i].toCharArray(), result);
        }
        return result;
    }
}
