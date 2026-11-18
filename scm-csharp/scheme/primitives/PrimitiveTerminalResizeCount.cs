namespace scheme;

public class PrimitiveTerminalResizeCount : Primitive
{
    public override string Name()
    {
        return "terminal-resize-count";
    }

    public override string Info()
    {
        return
            "Syntax: (terminal-resize-count)\n" +
            "Library: (scm terminal)\n" +
            "Description: Returns the number of terminal resize events (SIGWINCH)\n" +
            "seen since resize tracking started, or #f if resize events cannot be\n" +
            "observed on this platform. The first call starts tracking and returns 0.\n" +
            "Compare successive results to find out whether the terminal changed\n" +
            "size; while tracking is active, terminal-size is cached between resizes.\n" +
            "Example:\n" +
            "  (terminal-resize-count) => 0";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        if (!TerminalState.InstallResizeHandler())
            return Value.F;
        return TerminalState.ResizeCount;
    }
}
