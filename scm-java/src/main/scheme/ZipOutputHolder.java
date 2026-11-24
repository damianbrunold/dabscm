package scheme;

import java.io.ByteArrayOutputStream;
import java.io.FilterOutputStream;
import java.io.Flushable;
import java.io.IOException;
import java.io.OutputStream;
import java.util.zip.ZipOutputStream;

public class ZipOutputHolder {
    public ZipOutputStream zip;
    public ByteArrayOutputStream mem; // null for file-based zips
    // the port of the entry being written (zip-add-text-entry,
    // zip-add-binary-entry): what it buffers goes into its entry
    private Flushable current;

    public ZipOutputHolder(ZipOutputStream zip, ByteArrayOutputStream mem) {
        this.zip = zip;
        this.mem = mem;
    }

    // Before the next entry or the end of the zip: the entry port's
    // buffered output goes into its entry (it was lost unless flushed)
    public void finishEntry() {
        if (current == null) return;
        try {
            current.flush();
        } catch (IOException e) {
            // the port is closed: closing flushed it
        }
        current = null;
    }

    public void setCurrent(Flushable port) {
        current = port;
    }

    // The stream an entry port writes to: closing the port only flushes,
    // it does not close the zip (later entries were lost)
    public OutputStream entryStream() {
        return new FilterOutputStream(zip) {
            @Override
            public void write(byte[] b, int off, int len) throws IOException {
                out.write(b, off, len);
            }

            @Override
            public void close() throws IOException {
                flush();
            }
        };
    }
}
