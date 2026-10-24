package scheme.primitives;

import scheme.*;

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
        // Read byte by byte up to the newline: a buffered reader would
        // swallow the following lines (a second prompt would then see EOF).
        try {
            java.io.ByteArrayOutputStream buf = new java.io.ByteArrayOutputStream();
            int b = System.in.read();
            if (b == -1) return Value.EOF;
            while (b != -1 && b != '\n') {
                buf.write(b);
                b = System.in.read();
            }
            String line = buf.toString(java.nio.charset.StandardCharsets.UTF_8);
            if (line.endsWith("\r")) line = line.substring(0, line.length() - 1);
            return line.toCharArray();
        } catch (Exception e) {
            throw new SchemeError(pos, "console-read-password: io failure: ~s", e.getMessage());
        }
    }
}
