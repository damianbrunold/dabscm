package scheme.primitives;

import java.nio.channels.FileChannel;
import java.nio.channels.FileLock;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;

import scheme.*;

public class PrimitiveFileLock extends Primitive {
    @Override
    public String name() {
        return "file-lock";
    }

    @Override
    public String info() {
        return "Syntax: (file-lock path)\n" +
               "Library: (scm fs)\n" +
               "Description: Acquires an exclusive, OS-managed advisory lock on the file at\n" +
               "  path, creating the file (and any parent directories) if needed. Returns a\n" +
               "  lock handle on success, or #f if another process already holds the lock.\n" +
               "  Release it with file-unlock; the lock is also released automatically when\n" +
               "  the process exits, so it never goes stale.\n" +
               "Example:\n" +
               "  (define h (file-lock \"/tmp/app.lock\"))\n" +
               "  (when h (file-unlock h))";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        var path = new String(Value.asString(arguments[0]));
        try {
            Path p = LongPath.of(path);
            Path parent = p.getParent();
            if (parent != null) Files.createDirectories(parent);
            FileChannel channel = FileChannel.open(p,
                StandardOpenOption.READ, StandardOpenOption.WRITE, StandardOpenOption.CREATE);
            FileLock lock;
            try {
                lock = channel.tryLock();
            } catch (Exception e) {
                // OverlappingFileLockException: this JVM already holds the lock.
                channel.close();
                return Value.F;
            }
            if (lock == null) {
                channel.close();
                return Value.F;
            }
            return new NativeValue(new SchemeFileLock(channel, lock, path));
        } catch (Exception e) {
            return Value.F;
        }
    }
}
