using System.Runtime.InteropServices;

namespace scheme;

public class PrimitiveTerminalReadByte : Primitive
{
    public override string Name()
    {
        return "terminal-read-byte";
    }

    public override string Info()
    {
        return
            "Syntax: (terminal-read-byte)\n" +
            "Library: (scm terminal)\n" +
            "Description: Reads a single raw byte from standard input, bypassing\n" +
            "the port system and any line buffering. Returns an integer 0-255,\n" +
            "or an eof-object if the end of input has been reached.\n" +
            "Intended for use in raw terminal mode.\n" +
            "Example:\n" +
            "  (terminal-read-byte) => 27  ; ESC key";
    }

    [DllImport("libc", SetLastError = true)]
    private static extern nint read(int fd, byte[] buf, nint count);

    private const int EINTR = 4;

    private static Stream? rawStdin;
    private static readonly byte[] buf = new byte[1];

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        try
        {
            // On Unix, Console.OpenStandardInput() on a terminal reads through
            // .NET's line editor (echo, line buffering, ISIG back on), which
            // defeats terminal-raw!. Read fd 0 directly instead.
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                while (true)
                {
                    nint n = read(0, buf, 1);
                    if (n == 1) return (long) buf[0];
                    if (n == 0) return Value.EOF;
                    int errno = Marshal.GetLastWin32Error();
                    if (errno != EINTR)
                        throw new IOException("read failed, errno " + errno);
                }
            }
            if (rawStdin == null)
                rawStdin = Console.OpenStandardInput();
            int b = rawStdin.ReadByte();
            if (b == -1)
                return Value.EOF;
            return (long) b;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "terminal-read-byte: io failure: ~a", e.Message);
        }
    }
}
