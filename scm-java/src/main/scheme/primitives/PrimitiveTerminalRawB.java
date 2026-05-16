package scheme.primitives;

import scheme.*;
import java.io.BufferedReader;
import java.io.InputStreamReader;

public class PrimitiveTerminalRawB extends Primitive {
    private static String savedSttySettings = null;
    private static boolean isRaw = false;
    private static boolean shutdownHookInstalled = false;

    @Override
    public String name() {
        return "terminal-raw!";
    }

    @Override
    public String info() {
        return "Syntax: (terminal-raw! enable)\n" +
               "Library: (scm terminal)\n" +
               "Description: Enables or disables raw terminal mode.\n" +
               "When enable is #t, disables line buffering, echo, and signal\n" +
               "processing so that individual keypresses can be read.\n" +
               "When enable is #f, restores the original terminal settings.\n" +
               "Returns #t on success, #f if raw mode is not supported.\n" +
               "On Windows with Java, raw mode is not supported and returns #f.\n" +
               "Example:\n" +
               "  (terminal-raw! #t)  ; enable raw mode\n" +
               "  (terminal-raw! #f)  ; restore original mode";
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
            Runtime.getRuntime().addShutdownHook(new Thread(PrimitiveTerminalRawB::restoreTerminal));
            shutdownHookInstalled = true;
        }

        try {
            if (enable) {
                if (isRaw) return true;

                // Save current settings
                ProcessBuilder pbSave = new ProcessBuilder("stty", "-g");
                pbSave.redirectInput(new java.io.File("/dev/tty"));
                pbSave.redirectErrorStream(true);
                Process pSave = pbSave.start();
                BufferedReader reader = new BufferedReader(new InputStreamReader(pSave.getInputStream()));
                savedSttySettings = reader.readLine();
                pSave.waitFor();
                if (savedSttySettings == null || savedSttySettings.isEmpty())
                    return false;

                // Enable raw mode
                ProcessBuilder pbRaw = new ProcessBuilder("stty", "raw", "-echo", "-isig");
                pbRaw.redirectInput(new java.io.File("/dev/tty"));
                pbRaw.redirectErrorStream(true);
                int exitCode = pbRaw.start().waitFor();
                if (exitCode != 0)
                    return false;

                isRaw = true;
                return true;
            } else {
                if (!isRaw || savedSttySettings == null) return true;

                ProcessBuilder pbRestore = new ProcessBuilder("stty", savedSttySettings);
                pbRestore.redirectInput(new java.io.File("/dev/tty"));
                pbRestore.redirectErrorStream(true);
                int exitCode = pbRestore.start().waitFor();

                isRaw = false;
                savedSttySettings = null;
                return exitCode == 0;
            }
        } catch (Exception e) {
            return false;
        }
    }

    private static void restoreTerminal() {
        if (!isRaw || savedSttySettings == null) return;
        try {
            ProcessBuilder pb = new ProcessBuilder("stty", savedSttySettings);
            pb.redirectInput(new java.io.File("/dev/tty"));
            pb.redirectErrorStream(true);
            pb.start().waitFor();
            isRaw = false;
            savedSttySettings = null;
        } catch (Exception e) {
            // Best effort on shutdown
        }
    }
}
