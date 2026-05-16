package scheme.primitives;

import scheme.*;

public class PrimitiveTerminalEnableAnsiB extends Primitive {
    @Override
    public String name() {
        return "terminal-enable-ansi!";
    }

    @Override
    public String info() {
        return "Syntax: (terminal-enable-ansi!)\n" +
               "Library: (scm terminal)\n" +
               "Description: Enables ANSI escape sequence processing.\n" +
               "On Windows, this enables virtual terminal processing for the\n" +
               "console output and input handles. On Linux and macOS, this is\n" +
               "a no-op since ANSI is natively supported.\n" +
               "Returns #t on success, #f on failure.\n" +
               "Note: In the Java implementation, this is always a no-op.\n" +
               "Windows ANSI support requires a modern terminal emulator.\n" +
               "Example:\n" +
               "  (terminal-enable-ansi!) => #t";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        // On Java, ANSI processing depends on the terminal emulator.
        // Modern terminals (Windows Terminal, mintty, etc.) support it natively.
        // There is no portable Java API to enable it on older Windows consoles.
        return true;
    }
}
