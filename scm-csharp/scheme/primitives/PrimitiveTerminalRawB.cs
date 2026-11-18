using System.Runtime.InteropServices;

namespace scheme;

public class PrimitiveTerminalRawB : Primitive
{
    // Linux termios P/Invoke
    [DllImport("libc", SetLastError = true)]
    private static extern int tcgetattr(int fd, byte[] termios);

    [DllImport("libc", SetLastError = true)]
    private static extern int tcsetattr(int fd, int optional_actions, byte[] termios);

    [DllImport("libc")]
    private static extern void cfmakeraw(byte[] termios);

    // Windows console P/Invoke
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    private const int STDIN_FILENO = 0;
    private const int TCSANOW = 0;

    // Big enough for struct termios on Linux (60 bytes) and macOS (72 bytes);
    // the layout is left to libc (tcgetattr/cfmakeraw/tcsetattr).
    private const int TERMIOS_SIZE = 256;

    // Windows console constants
    private const int STD_INPUT_HANDLE = -10;
    private const uint ENABLE_LINE_INPUT = 0x0002;
    private const uint ENABLE_ECHO_INPUT = 0x0004;
    private const uint ENABLE_PROCESSED_INPUT = 0x0001;
    private const uint ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200;

    private static byte[]? savedTermios;
    private static uint? savedConsoleMode;
    private static bool isRaw = false;
    private static bool shutdownHookInstalled = false;

    public override string Name()
    {
        return "terminal-raw!";
    }

    public override string Info()
    {
        return
            "Syntax: (terminal-raw! enable)\n" +
            "Library: (scm terminal)\n" +
            "Description: Enables or disables raw terminal mode.\n" +
            "When enable is #t, disables line buffering, echo, signal processing,\n" +
            "flow control (Ctrl-S/Ctrl-Q), CR/NL translation of input and output\n" +
            "post-processing, so that individual keypresses can be read; write\n" +
            "\"\\r\\n\" to start a new line at column 1.\n" +
            "When enable is #f, restores the original terminal settings.\n" +
            "Returns #t on success, #f if raw mode is not supported.\n" +
            "Example:\n" +
            "  (terminal-raw! #t)  ; enable raw mode\n" +
            "  (terminal-raw! #f)  ; restore original mode";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        bool enable = !arguments[0].Equals(Value.F);

        if (Console.IsInputRedirected)
            return (object)false;

        if (!shutdownHookInstalled)
        {
            Console.CancelKeyPress += (sender, e) => RestoreTerminal();
            AppDomain.CurrentDomain.ProcessExit += (sender, e) => RestoreTerminal();
            shutdownHookInstalled = true;
        }

        try
        {
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                return (object)SetRawModeWindows(enable);
            else
                return (object)SetRawModeUnix(enable);
        }
        catch
        {
            return (object)false;
        }
    }

    private static bool SetRawModeUnix(bool enable)
    {
        if (enable)
        {
            if (isRaw) return true;

            savedTermios = new byte[TERMIOS_SIZE];
            if (tcgetattr(STDIN_FILENO, savedTermios) != 0)
                return false;

            byte[] raw = (byte[])savedTermios.Clone();

            // Same mode as `stty raw -echo -isig` on Java: no echo, no line
            // editing, no signals, no flow control (IXON), no CR/NL input
            // translation, no output post-processing (write "\r\n"),
            // VMIN=1/VTIME=0.
            cfmakeraw(raw);

            if (tcsetattr(STDIN_FILENO, TCSANOW, raw) != 0)
                return false;

            isRaw = true;
            return true;
        }
        else
        {
            if (!isRaw || savedTermios == null) return true;
            int result = tcsetattr(STDIN_FILENO, TCSANOW, savedTermios);
            isRaw = false;
            savedTermios = null;
            return result == 0;
        }
    }

    private static bool SetRawModeWindows(bool enable)
    {
        IntPtr handle = GetStdHandle(STD_INPUT_HANDLE);
        if (handle == IntPtr.Zero)
            return false;

        if (enable)
        {
            if (isRaw) return true;

            if (!GetConsoleMode(handle, out uint mode))
                return false;
            savedConsoleMode = mode;

            uint rawMode = mode;
            rawMode &= ~(ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT | ENABLE_PROCESSED_INPUT);
            rawMode |= ENABLE_VIRTUAL_TERMINAL_INPUT;

            if (!SetConsoleMode(handle, rawMode))
                return false;

            isRaw = true;
            return true;
        }
        else
        {
            if (!isRaw || savedConsoleMode == null) return true;
            bool result = SetConsoleMode(handle, savedConsoleMode.Value);
            isRaw = false;
            savedConsoleMode = null;
            return result;
        }
    }

    private static void RestoreTerminal()
    {
        if (!isRaw) return;
        try
        {
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                SetRawModeWindows(false);
            else
                SetRawModeUnix(false);
        }
        catch
        {
            // Best effort on shutdown
        }
    }
}
