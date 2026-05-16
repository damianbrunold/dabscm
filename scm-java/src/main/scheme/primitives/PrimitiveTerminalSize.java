package scheme.primitives;

import scheme.*;
import java.io.BufferedReader;
import java.io.InputStreamReader;

public class PrimitiveTerminalSize extends Primitive {
    @Override
    public String name() {
        return "terminal-size";
    }

    @Override
    public String info() {
        return "Syntax: (terminal-size)\n" +
               "Library: (scm terminal)\n" +
               "Description: Returns the terminal dimensions as a pair (cols . rows),\n" +
               "or #f if the terminal size cannot be determined.\n" +
               "Example:\n" +
               "  (terminal-size) => (80 . 24)";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 0, 0);
        if (System.console() == null)
            return false;
        try {
            String osName = System.getProperty("os.name").toLowerCase();
            if (osName.contains("windows")) {
                return getSizeWindows();
            } else {
                return getSizeUnix();
            }
        } catch (Exception e) {
            return false;
        }
    }

    private Object getSizeUnix() throws Exception {
        ProcessBuilder pb = new ProcessBuilder("stty", "size");
        pb.redirectInput(new java.io.File("/dev/tty"));
        pb.redirectErrorStream(true);
        Process p = pb.start();
        BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream()));
        String line = reader.readLine();
        int exitCode = p.waitFor();
        if (exitCode != 0 || line == null)
            return false;
        String[] parts = line.trim().split("\\s+");
        if (parts.length != 2)
            return false;
        int rows = Integer.parseInt(parts[0]);
        int cols = Integer.parseInt(parts[1]);
        if (rows <= 0 || cols <= 0)
            return false;
        return new Pair(cols, rows);
    }

    private Object getSizeWindows() throws Exception {
        ProcessBuilder pb = new ProcessBuilder("cmd.exe", "/c", "mode", "con");
        pb.redirectErrorStream(true);
        Process p = pb.start();
        BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream()));
        int cols = -1, rows = -1;
        String line;
        while ((line = reader.readLine()) != null) {
            line = line.trim().toLowerCase();
            if (line.contains("columns") || line.contains("spalten")) {
                String num = line.replaceAll("[^0-9]", "");
                if (!num.isEmpty()) cols = Integer.parseInt(num);
            }
            if (line.contains("lines") || line.contains("zeilen")) {
                String num = line.replaceAll("[^0-9]", "");
                if (!num.isEmpty()) rows = Integer.parseInt(num);
            }
        }
        p.waitFor();
        if (cols <= 0 || rows <= 0)
            return false;
        return new Pair(cols, rows);
    }
}
