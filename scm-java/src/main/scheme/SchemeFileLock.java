package scheme;

import java.io.File;
import java.nio.channels.FileChannel;
import java.nio.channels.FileLock;

// Opaque handle returned by the file-lock primitive. Holds the FileChannel
// and its FileLock; releasing the lock / closing the channel (explicitly via
// file-unlock, or implicitly on JVM exit) frees the OS lock, so it never goes
// stale.
public class SchemeFileLock {
    public FileChannel channel;
    public FileLock lock;
    public String path;

    public SchemeFileLock(FileChannel channel, FileLock lock, String path) {
        this.channel = channel;
        this.lock = lock;
        this.path = path;
    }

    public void release() {
        try { if (lock != null) lock.release(); } catch (Exception e) { }
        try { if (channel != null) channel.close(); } catch (Exception e) { }
        lock = null;
        channel = null;
    }

    @Override
    public String toString() {
        return "#<file-lock " + new File(path).getName() + ">";
    }
}
