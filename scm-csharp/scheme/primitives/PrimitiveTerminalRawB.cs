using System.Runtime.InteropServices;

namespace scheme;

public class PrimitiveTerminalRawB : Primitive
{
    // Linux termios P/Invoke
    [DllImport("libc", SetLastError = true)]
    private static extern int tcgetattr(int fd, byte[] termios);

    [DllImport("libc", SetLastError = true)]
    private static extern int tcsetattr(int fd, int optional_actions, byte[] termios);

    // Windows console P/Invoke
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    private const int STDIN_FILENO = 0;
    private const int TCSANOW = 0;

    // Linux termios flags
    private const uint ICANON = 0x00000002;
    private const uint ECHO   = 0x00000008;
    private const uint ISIG   = 0x00000001;

    // Offsets into the termios struct for x86-64 Linux
    // c_iflag: 0, c_oflag: 4, c_cflag: 8, c_lflag: 12
    // c_line: 16, c_cc[32]: 17, c_ispeed: 52, c_ospeed: 56
    private const int LFLAG_OFFSET = 12;
    private const int CC_OFFSET = 17;
    private const int VMIN_INDEX = 6;
    private const int VTIME_INDEX = 5;
    private const int TERMIOS_SIZE = 60;

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
            "When enable is #t, disables line buffering, echo, and signal\n" +
            "processing so that individual keypresses can be read.\n" +
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

            // Clear ICANON, ECHO, ISIG in c_lflag
            uint lflag = BitConverter.ToUInt32(raw, LFLAG_OFFSET);
            lflag &= ~(ICANON | ECHO | ISIG);
            BitConverter.GetBytes(lflag).CopyTo(raw, LFLAG_OFFSET);

            // Set VMIN=1, VTIME=0
            raw[CC_OFFSET + VMIN_INDEX] = 1;
            raw[CC_OFFSET + VTIME_INDEX] = 0;

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
