package scheme;

import java.io.PushbackReader;
import java.io.IOException;

public class TextStream {
    private PushbackReader reader;
    private String filename;
    private int line = 1;
    private int column = 0;

    public boolean foldCase = false;
    public boolean isOpen = true;

    public TextStream(PushbackReader reader, String filename) {
        this.reader = reader;
        this.filename = filename;
    }

    public void close() throws IOException {
        isOpen = false;
        this.reader.close();
    }

    public void setPosition(int line, int column) {
        this.line = line;
        this.column = column;
    }

    public String readToEnd() throws IOException {
        StringBuilder result = new StringBuilder();
        char[] buffer = new char[10240];
        int read = this.reader.read(buffer);
        while (read > 0) {
            result.append(buffer, 0, read);
            read = this.reader.read(buffer);
        }
        // TODO do we need to track the position here? probably not...
        return result.toString();
    }

    public String readLine() throws IOException {
        StringBuilder result = new StringBuilder();
        while (true) {
            int c = reader.read();
            if (c == -1) break;
            if (c == '\r' || c == '\n') {
                if (c == '\r' && peek() == '\n') {
                    reader.read();
                }
                return result.toString();
            }
            result.append((char) c);
        }
        if (result.length() > 0) {
            this.line++;
            this.column = 0;
            return result.toString();
        }
        return null;
    }

    public int read() throws IOException {
        int c = this.reader.read();
        if (c == '\n') {
            this.line++;
            this.column = 0;
        } else {
            this.column++;
        }
        return c;
    }

    public int peek() throws IOException {
        int c = this.reader.read();
        if (c != -1) {
            this.reader.unread(c);
        }
        return c;
    }

    public String filename() {
        return filename;
    }

    public int line() {
        return line;
    }

    public int column() {
        return column;
    }

    public SourcePos pos() {
        return new SourcePos(filename, line, column);
    }
}
