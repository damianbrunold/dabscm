package scheme.primitives;

import scheme.*;

public class PrimitiveSetExitCode extends Primitive {
    @Override
    public String name() {
        return "set-exit-code!";
    }

    @Override
    public String info() {
        return "Syntax: (set-exit-code! code)\n" +
               "Library: (scheme process-context)\n" +
               "Description: Records the exit code the process should return when the\n" +
               "  current script finishes, without terminating immediately (unlike exit).\n" +
               "  The standalone script runner honours this after the script completes.\n" +
               "  code must be an exact integer. Returns an unspecified value.\n" +
               "Example:\n" +
               "  (set-exit-code! 1)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        Scheme.pendingExitCode = IntegerMath.toInt(arguments[0]);
        return new Values();
    }
}
