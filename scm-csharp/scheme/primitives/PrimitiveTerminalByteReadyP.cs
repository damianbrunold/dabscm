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
            "Syntax: (terminal-byte-ready? [timeout-ms])\n" +
            "Library: (scm terminal)\n" +
            "Description: Returns #t if a byte is available for reading from\n" +
            "standard input without blocking, #f otherwise. With timeout-ms,\n" +
            "waits up to that many milliseconds for a byte to arrive.\n" +
            "Intended for use in raw terminal mode to detect multi-byte\n" +
            "escape sequences.\n" +
            "Example:\n" +
            "  (terminal-byte-ready?) => #f\n" +
            "  (terminal-byte-ready? 50) => #t  ; a key arrived within 50 ms";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);
        long timeout = arguments.Length > 0 ? IntegerMath.ToLong(arguments[0]) : 0;
        if (timeout < 0) timeout = 0;
        if (timeout > int.MaxValue) timeout = int.MaxValue;
        try
        {
            // On Unix, Console.KeyAvailable initializes .NET's own terminal
            // handling, which resets the termios set by terminal-raw! (echo and
            // line buffering come back). Poll fd 0 directly instead; that also
            // matches terminal-read-byte, which reads the raw stdin stream.
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                var fds = new[] { new PollFd { fd = 0, events = POLLIN } };
                var deadline = Environment.TickCount64 + timeout;
                while (true)
                {
                    int wait = (int)Math.Max(0, deadline - Environment.TickCount64);
                    int r = poll(fds, 1, wait);
                    if (r > 0) return (object)((fds[0].revents & POLLIN) != 0);
                    if (r == 0) return (object)false;
                    // EINTR (e.g. SIGWINCH): retry with the remaining time
                    if (Marshal.GetLastWin32Error() != 4) return (object)false;
                    fds[0].revents = 0;
                }
            }
            if (!Console.IsInputRedirected)
            {
                var until = Environment.TickCount64 + timeout;
                while (!Console.KeyAvailable)
                {
                    if (Environment.TickCount64 >= until) return (object)false;
                    Thread.Sleep(3);
                }
                return (object)true;
            }
            return (object)(Console.In.Peek() != -1);
        }
        catch
        {
            return (object)false;
        }
    }
}
