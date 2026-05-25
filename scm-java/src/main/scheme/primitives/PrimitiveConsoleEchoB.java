package scheme.primitives;

import scheme.*;
import java.io.BufferedReader;
import java.io.InputStreamReader;

public class PrimitiveConsoleEchoB extends Primitive {
    private static Boolean savedEcho = null;
    private static boolean shutdownHookInstalled = false;

    @Override
    public String name() {
        return "console-echo!";
    }

    @Override
    public String info() {
        return "Syntax: (console-echo! enable)\n" +
               "Library: (scm terminal)\n" +
               "Description: Enables or disables echoing of typed characters\n" +
               "on the terminal. Unlike terminal-raw!, line buffering and\n" +
               "signal processing are left untouched, so the user can still\n" +
               "edit the line and press enter before it is delivered. The\n" +
               "primary use is reading a password.\n" +
               "Returns #t on success, #f if not supported (e.g. when stdin\n" +
               "is not a terminal). On the Java implementation under\n" +
               "Windows, console-echo! returns #f because stty is not\n" +
               "available there — use console-read-password instead.\n" +
               "A shutdown hook restores echo on exit.\n" +
               "Example:\n" +
               "  (console-echo! #f)  ; disable echo\n" +
               "  (read-line)         ; read password silently\n" +
               "  (console-echo! #t)  ; re-enable echo";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        boolean enable = arguments[0] != Value.F;

        if (System.console() == null)
            return false;

        String osName = System.getProperty("os.name").toLowerCase();
        if (osName.contains("windows"))
            return false;

        if (!shutdownHookInstalled) {
            Runtime.getRuntime().addShutdownHook(new Thread(PrimitiveConsoleEchoB::restoreEcho));
            shutdownHookInstalled = true;
        }

        try {
            if (savedEcho == null)
                savedEcho = readCurrentEcho();
            return setEcho(enable);
        } catch (Exception e) {
            return false;
        }
    }

    private static Boolean readCurrentEcho() {
        try {
            ProcessBuilder pb = new ProcessBuilder("stty", "-a");
            pb.redirectInput(new java.io.File("/dev/tty"));
            pb.redirectErrorStream(true);
            Process p = pb.start();
            BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream()));
            StringBuilder out = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null)
                out.append(line).append(' ');
            p.waitFor();
            // "echo" with no leading "-" means echo is on; "-echo" means off.
            // Match as a whole word.
            String s = out.toString();
            // Look for " -echo " (off) preferentially over "echo".
            return !s.matches(".*(^|\\W)-echo(\\W|$).*");
        } catch (Exception e) {
            return true; // assume echo was on
        }
    }

    private static boolean setEcho(boolean enable) {
        try {
            ProcessBuilder pb = new ProcessBuilder(
                "stty", enable ? "echo" : "-echo");
            pb.redirectInput(new java.io.File("/dev/tty"));
            pb.redirectErrorStream(true);
            return pb.start().waitFor() == 0;
        } catch (Exception e) {
            return false;
        }
    }

    private static void restoreEcho() {
        if (savedEcho == null) return;
        try {
            setEcho(savedEcho);
        } catch (Exception e) {
            // Best effort on shutdown
        }
    }
}
