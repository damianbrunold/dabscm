namespace scheme;

/// file-mode, set-file-mode! and real-path ((scm fs))
public class PrimitiveFileMode : Primitive
{
    private readonly string name;

    public PrimitiveFileMode(string name)
    {
        this.name = name;
    }

    public override string Name() => name;

    public override string Info() => name switch
    {
        "file-mode" =>
            "Syntax: (file-mode path)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns the permission bits of path as an integer (as chmod\n" +
            "  takes them), or #f on Windows or if path does not exist.\n" +
            "Example:\n" +
            "  (number->string (file-mode \"script.sh\") 8) => \"755\"",
        "set-file-mode!" =>
            "Syntax: (set-file-mode! path mode)\n" +
            "Library: (scm fs)\n" +
            "Description: Sets the permission bits of path to the integer mode, in the\n" +
            "  process (no chmod program). Returns #t, or #f on Windows or failure.\n" +
            "Example:\n" +
            "  (set-file-mode! \"script.sh\" #o755) => #t",
        _ =>
            "Syntax: (real-path path)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns path made absolute with . and .. and symbolic links\n" +
            "  resolved, or #f if path does not exist.\n" +
            "Example:\n" +
            "  (real-path \"link/../file.txt\") => \"/home/me/file.txt\"",
    };

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        if (name == "set-file-mode!") CheckArgs(pos, arguments, 2, 2);
        else CheckArgs(pos, arguments, 1, 1);
        string path = new string(Value.AsString(arguments[0]));
        try
        {
            switch (name)
            {
                case "file-mode":
                    if (OperatingSystem.IsWindows() || !Path.Exists(path)) return Value.F;
                    return (long)File.GetUnixFileMode(path);
                case "set-file-mode!":
                {
                    long mode = IntegerMath.ToLong(arguments[1]);
                    if (mode < 0 || mode > 4095) throw new SchemeError(pos, "set-file-mode!: wrong argument type");
                    if (OperatingSystem.IsWindows()) return Value.F;
                    File.SetUnixFileMode(path, (UnixFileMode)mode);
                    return Value.T;
                }
                default:
                    return RealPath(path) is string r ? r.ToCharArray() : Value.F;
            }
        }
        catch (SchemeError)
        {
            throw;
        }
        catch (Exception e) when (e is IOException || e is UnauthorizedAccessException || e is PlatformNotSupportedException)
        {
            return Value.F;
        }
    }

    // each component's symbolic link resolved, from the root down, with . and ..
    // applied to the resolved path (as realpath(3))
    static string? RealPath(string path)
    {
        string full = Path.GetFullPath(path);
        if (!Path.Exists(full)) return null;
        string root = Path.GetPathRoot(full)!;
        string current = root;
        var rest = new Queue<string>(full.Substring(root.Length).Split(Path.DirectorySeparatorChar, StringSplitOptions.RemoveEmptyEntries));
        int hops = 0;
        while (rest.Count > 0)
        {
            string part = rest.Dequeue();
            if (part == ".") continue;
            if (part == "..") { current = Path.GetDirectoryName(current) ?? root; continue; }
            string next = Path.Combine(current, part);
            FileSystemInfo info = Directory.Exists(next) ? new DirectoryInfo(next) : new FileInfo(next);
            if (info.LinkTarget is string target)
            {
                if (++hops > 40) return null;
                string t = Path.IsPathRooted(target) ? target : Path.Combine(current, target);
                string tf = Path.GetFullPath(t);
                string troot = Path.GetPathRoot(tf)!;
                var parts = tf.Substring(troot.Length).Split(Path.DirectorySeparatorChar, StringSplitOptions.RemoveEmptyEntries);
                var q = new Queue<string>(parts.Concat(rest));
                rest = q;
                current = troot;
                continue;
            }
            current = next;
        }
        return current;
    }
}
