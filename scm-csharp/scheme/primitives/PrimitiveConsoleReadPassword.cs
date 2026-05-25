using System.Text;

namespace scheme;

public class PrimitiveConsoleReadPassword : Primitive
{
    public override string Name()
    {
        return "console-read-password";
    }

    public override string Info()
    {
        return
            "Syntax: (console-read-password)\n" +
            "Syntax: (console-read-password prompt)\n" +
            "Library: (scm terminal)\n" +
            "Description: Reads a line from the terminal without echoing\n" +
            "the typed characters. If prompt is given, it is displayed\n" +
            "before reading. Backspace erases the last character; enter\n" +
            "ends the line. Returns the entered string (without the\n" +
            "trailing newline), or the eof-object if input is closed.\n" +
            "When stdin is redirected, this falls back to read-line\n" +
            "behaviour on the underlying stream.\n" +
            "Example:\n" +
            "  (console-read-password \"Password: \")";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 1);

        if (arguments.Length == 1)
        {
            if (!Value.IsString(arguments[0]))
                throw new SchemeError(pos, "console-read-password: expected string prompt, got ~s", arguments[0]);
            Console.Write(new string(Value.AsString(arguments[0])));
        }

        if (Console.IsInputRedirected)
        {
            string? line = Console.In.ReadLine();
            if (line == null) return Value.EOF;
            return line.ToCharArray();
        }

        StringBuilder sb = new StringBuilder();
        while (true)
        {
            ConsoleKeyInfo k;
            try
            {
                k = Console.ReadKey(intercept: true);
            }
            catch (InvalidOperationException)
            {
                string? line = Console.In.ReadLine();
                if (line == null && sb.Length == 0) return Value.EOF;
                return (sb.ToString() + (line ?? "")).ToCharArray();
            }

            if (k.Key == ConsoleKey.Enter)
            {
                Console.WriteLine();
                return sb.ToString().ToCharArray();
            }
            else if (k.Key == ConsoleKey.Backspace)
            {
                if (sb.Length > 0)
                    sb.Length--;
            }
            else if (k.KeyChar != '\0' && !char.IsControl(k.KeyChar))
            {
                sb.Append(k.KeyChar);
            }
        }
    }
}
