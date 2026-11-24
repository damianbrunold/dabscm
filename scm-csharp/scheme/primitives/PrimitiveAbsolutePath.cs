namespace scheme;

public class PrimitiveAbsolutePath : Primitive
{
    public override string Name()
    {
        return "absolute-path";
    }

    public override string Info()
    {
        return
            "Syntax: (absolute-path path)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns the absolute (fully qualified) form of the given path string.\n" +
            "Example:\n" +
            "  (absolute-path \".\") => \"/current/working/dir\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var path = new String(Value.AsString(arguments[0]));
        return JavaAbsolute(path).ToCharArray();
    }

    // As the JVM's File.getAbsolutePath: on the current directory unless
    // absolute, separators made single and none at the end; .. is not
    // resolved (Path.GetFullPath did); on Windows backslashes, and a path
    // without a drive on the current drive
    internal static string JavaAbsolute(string path)
    {
        char sep = Path.DirectorySeparatorChar;
        string cwd = Directory.GetCurrentDirectory();
        string p = OperatingSystem.IsWindows() ? path.Replace('/', '\\') : path;
        string abs;
        if (Path.IsPathFullyQualified(p)) abs = p;
        else if (OperatingSystem.IsWindows() && p.StartsWith("\\")) abs = Path.GetPathRoot(cwd)!.TrimEnd('\\') + p;
        else if (OperatingSystem.IsWindows() && p.Length >= 2 && p[1] == ':')
            abs = char.ToLowerInvariant(cwd[0]) == char.ToLowerInvariant(p[0])
                ? Path.Combine(cwd, p.Substring(2))
                : p.Substring(0, 2) + "\\" + p.Substring(2);
        else abs = p.Length == 0 ? cwd : Path.Combine(cwd, p);
        var sb = new System.Text.StringBuilder();
        for (int i = 0; i < abs.Length; i++)
        {
            char c = abs[i];
            if (c == sep && sb.Length > 0 && sb[sb.Length - 1] == sep && !(sep == '\\' && i == 1)) continue;
            sb.Append(c);
        }
        while (sb.Length > 1 && sb[sb.Length - 1] == sep
               && !(sep == '\\' && sb.Length == 3 && sb[1] == ':')
               && !(sep == '\\' && sb.Length == 2 && sb[0] == sep))
            sb.Length--;
        return sb.ToString();
    }
}
