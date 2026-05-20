using System.Runtime.InteropServices;

namespace schemerepl;

/// <summary>
/// Minimal terminal driver. Console.ReadKey(intercept) already does the
/// raw-mode work on every supported platform; we add an extra one-shot
/// step on Windows to enable ENABLE_VIRTUAL_TERMINAL_PROCESSING so ANSI
/// escapes are interpreted by cmd / PowerShell / legacy consoles.
/// </summary>
public sealed class Terminal
{
    private bool vtEnabled;

    public bool CanRaw()
    {
        if (Console.IsInputRedirected || Console.IsOutputRedirected) return false;
        var term = Environment.GetEnvironmentVariable("TERM");
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            return true; // ReadKey works regardless of TERM
        return !(term == null || term.Length == 0 || term == "dumb");
    }

    public void EnsureVt()
    {
        if (vtEnabled) return;
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            try { EnableWindowsVt(); } catch { /* ignore */ }
        }
        vtEnabled = true;
    }

    public void Write(string s)
    {
        Console.Out.Write(s);
        Console.Out.Flush();
    }

    public int Width()
    {
        try
        {
            int w = Console.WindowWidth;
            return w > 0 ? w : 80;
        }
        catch { return 80; }
    }

    public ConsoleKeyInfo ReadKey() => Console.ReadKey(intercept: true);

    // ---- Windows VT enable ----

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    private const int STD_OUTPUT_HANDLE = -11;
    private const uint ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;

    private static void EnableWindowsVt()
    {
        var h = GetStdHandle(STD_OUTPUT_HANDLE);
        if (h == IntPtr.Zero || h == (IntPtr)(-1)) return;
        if (!GetConsoleMode(h, out var mode)) return;
        SetConsoleMode(h, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
    }
}
