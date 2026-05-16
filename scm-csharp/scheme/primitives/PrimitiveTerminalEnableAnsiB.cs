using System.Runtime.InteropServices;

namespace scheme;

public class PrimitiveTerminalEnableAnsiB : Primitive
{
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    private const int STD_OUTPUT_HANDLE = -11;
    private const int STD_INPUT_HANDLE = -10;
    private const uint ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;
    private const uint ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200;

    public override string Name()
    {
        return "terminal-enable-ansi!";
    }

    public override string Info()
    {
        return
            "Syntax: (terminal-enable-ansi!)\n" +
            "Library: (scm terminal)\n" +
            "Description: Enables ANSI escape sequence processing.\n" +
            "On Windows, this enables virtual terminal processing for the\n" +
            "console output and input handles. On Linux and macOS, this is\n" +
            "a no-op since ANSI is natively supported.\n" +
            "Returns #t on success, #f on failure.\n" +
            "Example:\n" +
            "  (terminal-enable-ansi!) => #t";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);

        if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            return (object)true;

        try
        {
            // Enable ANSI on stdout
            IntPtr outHandle = GetStdHandle(STD_OUTPUT_HANDLE);
            if (outHandle != IntPtr.Zero && GetConsoleMode(outHandle, out uint outMode))
            {
                outMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
                SetConsoleMode(outHandle, outMode);
            }

            // Enable ANSI on stdin
            IntPtr inHandle = GetStdHandle(STD_INPUT_HANDLE);
            if (inHandle != IntPtr.Zero && GetConsoleMode(inHandle, out uint inMode))
            {
                inMode |= ENABLE_VIRTUAL_TERMINAL_INPUT;
                SetConsoleMode(inHandle, inMode);
            }

            return (object)true;
        }
        catch
        {
            return (object)false;
        }
    }
}
