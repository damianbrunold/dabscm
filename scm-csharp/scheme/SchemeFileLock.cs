using System.IO;

namespace scheme;

// Opaque handle returned by the file-lock primitive. Holds the FileStream
// whose FileShare.None open IS the exclusive OS lock; closing the stream
// (explicitly via file-unlock, or implicitly on process exit) releases it,
// so the lock never goes stale.
public class SchemeFileLock
{
    public FileStream? stream;
    public string path;

    public SchemeFileLock(FileStream stream, string path)
    {
        this.stream = stream;
        this.path = path;
    }

    public void Release()
    {
        try { stream?.Close(); } catch { }
        stream = null;
    }

    public override string ToString()
    {
        return "#<file-lock " + Path.GetFileName(path) + ">";
    }
}
