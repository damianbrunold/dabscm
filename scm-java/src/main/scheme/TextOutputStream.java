package scheme;

import java.io.IOException;
import java.io.Writer;

public class TextOutputStream extends Writer {
    private Writer writer;
    public boolean isOpen = true;

    public TextOutputStream(Writer writer) {
        this.writer = writer;
    }

    public Writer getInner() {
        return writer;
    }

    private void ensureOpen() throws IOException {
        if (!isOpen) throw new IOException("port is closed");
    }

    @Override
    public void write(char[] cbuf, int off, int len) throws IOException {
        ensureOpen();
        writer.write(cbuf, off, len);
    }

    @Override
    public void write(int c) throws IOException {
        ensureOpen();
        writer.write(c);
    }

    @Override
    public void write(String str, int off, int len) throws IOException {
        ensureOpen();
        writer.write(str, off, len);
    }

    @Override
    public void flush() throws IOException {
        writer.flush();
    }

    @Override
    public void close() throws IOException {
        isOpen = false;
        writer.close();
    }

    @Override
    public String toString() {
        return writer.toString();
    }
}
