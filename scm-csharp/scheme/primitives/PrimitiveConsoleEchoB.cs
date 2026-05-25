using System.Runtime.InteropServices;

namespace scheme;

public class PrimitiveConsoleEchoB : Primitive
{
    [DllImport("libc", SetLastError = true)]
    private static extern int tcgetattr(int fd, byte[] termios);

    [DllImport("libc", SetLastError = true)]
    private static extern int tcsetattr(int fd, int optional_actions, byte[] termios);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    private const int STDIN_FILENO = 0;
    private const int TCSANOW = 0;

    // Linux termios c_lflag bits
    private const uint ECHO   = 0x00000008;
    private const uint ECHONL = 0x00000040;
    private const int LFLAG_OFFSET = 12;
    private const int TERMIOS_SIZE = 60;

    // Windows console constants
    private const int STD_INPUT_HANDLE = -10;
    private const uint ENABLE_ECHO_INPUT = 0x0004;

    private static bool? savedEcho;
    private static bool shutdownHookInstalled = false;

    public override string Name()
    {
        return "console-echo!";
    }

    public override string Info()
    {
        return
            "Syntax: (console-echo! enable)\n" +
            "Library: (scm terminal)\n" +
            "Description: Enables or disables echoing of typed characters\n" +
            "on the terminal. Unlike terminal-raw!, line buffering and\n" +
            "signal processing are left untouched, so the user can still\n" +
            "edit the line and press enter before it is delivered. The\n" +
            "primary use is reading a password.\n" +
            "Returns #t on success, #f if not supported (e.g. when stdin\n" +
            "is not a terminal). A shutdown hook restores echo on exit.\n" +
            "Example:\n" +
            "  (console-echo! #f)  ; disable echo\n" +
            "  (read-line)         ; read password silently\n" +
            "  (console-echo! #t)  ; re-enable echo";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        bool enable = !arguments[0].Equals(Value.F);

        if (Console.IsInputRedirected)
            return (object)false;

        if (!shutdownHookInstalled)
        {
            Console.CancelKeyPress += (sender, e) => RestoreEcho();
            AppDomain.CurrentDomain.ProcessExit += (sender, e) => RestoreEcho();
            shutdownHookInstalled = true;
        }

        try
        {
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                return (object)SetEchoWindows(enable);
            else
                return (object)SetEchoUnix(enable);
        }
        catch
        {
            return (object)false;
        }
    }

    private static bool SetEchoUnix(bool enable)
    {
        byte[] t = new byte[TERMIOS_SIZE];
        if (tcgetattr(STDIN_FILENO, t) != 0)
            return false;

        uint lflag = BitConverter.ToUInt32(t, LFLAG_OFFSET);
        if (savedEcho == null)
            savedEcho = (lflag & ECHO) != 0;

        if (enable)
            lflag |= ECHO;
        else
            lflag &= ~(ECHO | ECHONL);

        BitConverter.GetBytes(lflag).CopyTo(t, LFLAG_OFFSET);
        return tcsetattr(STDIN_FILENO, TCSANOW, t) == 0;
    }

    private static bool SetEchoWindows(bool enable)
    {
        IntPtr handle = GetStdHandle(STD_INPUT_HANDLE);
        if (handle == IntPtr.Zero)
            return false;

        if (!GetConsoleMode(handle, out uint mode))
            return false;

        if (savedEcho == null)
            savedEcho = (mode & ENABLE_ECHO_INPUT) != 0;

        if (enable)
            mode |= ENABLE_ECHO_INPUT;
        else
            mode &= ~ENABLE_ECHO_INPUT;

        return SetConsoleMode(handle, mode);
    }

    private static void RestoreEcho()
    {
        if (savedEcho == null) return;
        try
        {
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                SetEchoWindows(savedEcho.Value);
            else
                SetEchoUnix(savedEcho.Value);
        }
        catch
        {
            // Best effort on shutdown
        }
    }
}
