using System.Runtime.InteropServices;

namespace scheme;

public class PrimitiveTerminalSize : Primitive
{
    [StructLayout(LayoutKind.Sequential)]
    private struct WinSize
    {
        public ushort ws_row;
        public ushort ws_col;
        public ushort ws_xpixel;
        public ushort ws_ypixel;
    }

    [DllImport("libc", SetLastError = true)]
    private static extern int ioctl(int fd, ulong request, ref WinSize ws);

    private const ulong TIOCGWINSZ_LINUX = 0x5413;
    private const ulong TIOCGWINSZ_MACOS = 0x40087468;

    public override string Name()
    {
        return "terminal-size";
    }

    public override string Info()
    {
        return
            "Syntax: (terminal-size)\n" +
            "Library: (scm terminal)\n" +
            "Description: Returns the terminal dimensions as a pair (cols . rows),\n" +
            "or #f if the terminal size cannot be determined. While resize tracking\n" +
            "is active (see terminal-resize-count) the size is cached until the\n" +
            "next resize.\n" +
            "Example:\n" +
            "  (terminal-size) => (80 . 24)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        var cached = TerminalState.CachedSize;
        if (cached != null && TerminalState.ResizeTracked)
            return cached;
        try
        {
            if (Console.IsOutputRedirected && Console.IsInputRedirected)
                return (object)false;
            int cols = 0, rows = 0;
            // Ask the tty directly on Unix: Console.WindowWidth may initialize
            // .NET's terminal handling, which resets the termios of terminal-raw!.
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                ulong request = RuntimeInformation.IsOSPlatform(OSPlatform.OSX)
                    ? TIOCGWINSZ_MACOS : TIOCGWINSZ_LINUX;
                foreach (int fd in new[] { 1, 0, 2 })
                {
                    var ws = new WinSize();
                    if (ioctl(fd, request, ref ws) == 0 && ws.ws_col > 0 && ws.ws_row > 0)
                    {
                        cols = ws.ws_col;
                        rows = ws.ws_row;
                        break;
                    }
                }
            }
            if (cols <= 0 || rows <= 0)
            {
                cols = Console.WindowWidth;
                rows = Console.WindowHeight;
            }
            if (cols <= 0 || rows <= 0)
                return (object)false;
            object size = new Pair((long) cols, (long) rows);
            if (TerminalState.ResizeTracked)
                TerminalState.CachedSize = size;
            return size;
        }
        catch
        {
            return (object)false;
        }
    }
}
