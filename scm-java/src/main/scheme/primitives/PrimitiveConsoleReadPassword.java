package scheme.primitives;

import scheme.*;
import java.io.BufferedReader;
import java.io.InputStreamReader;

public class PrimitiveConsoleReadPassword extends Primitive {
    @Override
    public String name() {
        return "console-read-password";
    }

    @Override
    public String info() {
        return "Syntax: (console-read-password)\n" +
               "Syntax: (console-read-password prompt)\n" +
               "Library: (scm terminal)\n" +
               "Description: Reads a line from the terminal without echoing\n" +
               "the typed characters. If prompt is given, it is displayed\n" +
               "before reading. Returns the entered string (without the\n" +
               "trailing newline), or the eof-object if input is closed.\n" +
               "When stdin is redirected, this falls back to read-line\n" +
               "behaviour on the underlying stream.\n" +
               "Example:\n" +
               "  (console-read-password \"Password: \")";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 1);
        String prompt = "";
        if (arguments.length == 1) {
            if (!(arguments[0] instanceof char[]))
                throw new SchemeError(pos, "console-read-password: expected string prompt, got ~s", arguments[0]);
            prompt = new String((char[]) arguments[0]);
        }

        java.io.Console console = System.console();
        if (console != null) {
            char[] pw = console.readPassword("%s", prompt);
            if (pw == null) return Value.EOF;
            return pw;
        }

        // No console (e.g. stdin redirected): just read a line.
        if (!prompt.isEmpty()) {
            System.out.print(prompt);
            System.out.flush();
        }
        try {
            BufferedReader br = new BufferedReader(new InputStreamReader(System.in));
            String line = br.readLine();
            if (line == null) return Value.EOF;
            return line.toCharArray();
        } catch (Exception e) {
            throw new SchemeError(pos, "console-read-password: io failure: ~s", e.getMessage());
        }
    }
}
