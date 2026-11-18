package scheme.primitives;

import scheme.*;

public class PrimitiveTerminalResizeCount extends Primitive {
    @Override
    public String name() {
        return "terminal-resize-count";
    }

    @Override
    public String info() {
        return "Syntax: (terminal-resize-count)\n" +
               "Library: (scm terminal)\n" +
               "Description: Returns the number of terminal resize events (SIGWINCH)\n" +
               "seen since resize tracking started, or #f if resize events cannot be\n" +
               "observed on this platform. The first call starts tracking and returns 0.\n" +
               "Compare successive results to find out whether the terminal changed\n" +
               "size; while tracking is active, terminal-size is cached between resizes.\n" +
               "Example:\n" +
               "  (terminal-resize-count) => 0";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        if (!TerminalState.installResizeHandler())
            return Value.F;
        return TerminalState.resizeCount();
    }
}
