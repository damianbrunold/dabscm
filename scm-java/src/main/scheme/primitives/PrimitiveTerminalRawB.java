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
        return "Syntax: (terminal-raw! enable [keep-output])\n" +
               "Library: (scm terminal)\n" +
               "Description: Enables or disables raw terminal mode.\n" +
               "When enable is #t, disables line buffering, echo, signal processing,\n" +
               "flow control (Ctrl-S/Ctrl-Q), CR/NL translation of input and output\n" +
               "post-processing, so that individual keypresses can be read; write\n" +
               "\"\\r\\n\" to start a new line at column 1.\n" +
               "With 'keep-output as second argument, output post-processing stays on, so\n" +
               "that \"\\n\" also returns the carriage (Windows has no such processing).\n" +
               "When enable is #f, restores the original terminal settings.\n" +
               "Returns #t on success, #f if raw mode is not supported.\n" +
               "On Windows with Java, raw mode is not supported and returns #f.\n" +
               "Example:\n" +
               "  (terminal-raw! #t)  ; enable raw mode\n" +
               "  (terminal-raw! #f)  ; restore original mode";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 2);
        boolean enable = arguments[0] != Value.F;
        boolean keepOutput = false;
        if (arguments.length > 1) {
            if (!Value.isSymbol(arguments[1]) || !Value.asSymbol(arguments[1]).equals("keep-output"))
                throw new SchemeError(pos, "terminal-raw!: expected 'keep-output");
            keepOutput = true;
        }

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
                if (isRaw) return stty(keepOutput ? "opost" : "-opost");

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
                if (!stty("raw", "-echo", "-isig", keepOutput ? "opost" : "-opost"))
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

    private static boolean stty(String... settings) throws Exception {
        String[] cmd = new String[settings.length + 1];
        cmd[0] = "stty";
        System.arraycopy(settings, 0, cmd, 1, settings.length);
        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.redirectInput(new java.io.File("/dev/tty"));
        pb.redirectErrorStream(true);
        return pb.start().waitFor() == 0;
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
