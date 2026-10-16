using System.Runtime.InteropServices;

namespace scheme;

public class PrimitiveTerminalByteReadyP : Primitive
{
    [StructLayout(LayoutKind.Sequential)]
    private struct PollFd
    {
        public int fd;
        public short events;
        public short revents;
    }

    [DllImport("libc", SetLastError = true)]
    private static extern int poll([In, Out] PollFd[] fds, ulong nfds, int timeout);

    private const short POLLIN = 0x0001;

    public override string Name()
    {
        return "terminal-byte-ready?";
    }

    public override string Info()
    {
        return
            "Syntax: (terminal-byte-ready?)\n" +
            "Library: (scm terminal)\n" +
            "Description: Returns #t if a byte is available for reading from\n" +
            "standard input without blocking, #f otherwise.\n" +
            "Intended for use in raw terminal mode to detect multi-byte\n" +
            "escape sequences.\n" +
            "Example:\n" +
            "  (terminal-byte-ready?) => #f";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        try
        {
            // On Unix, Console.KeyAvailable initializes .NET's own terminal
            // handling, which resets the termios set by terminal-raw! (echo and
            // line buffering come back). Poll fd 0 directly instead; that also
            // matches terminal-read-byte, which reads the raw stdin stream.
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                var fds = new[] { new PollFd { fd = 0, events = POLLIN } };
                return (object)(poll(fds, 1, 0) > 0 && (fds[0].revents & POLLIN) != 0);
            }
            if (!Console.IsInputRedirected)
                return (object)Console.KeyAvailable;
            return (object)(Console.In.Peek() != -1);
        }
        catch
        {
            return (object)false;
        }
    }
}
