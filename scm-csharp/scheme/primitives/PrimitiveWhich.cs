namespace scheme;

public class PrimitiveWhich : Primitive
{
    public override string Name()
    {
        return "which";
    }

    public override string Info()
    {
        return
            "Syntax: (which program)\n" +
            "Library: (scm fs)\n" +
            "Description: Searches the directories in PATH for an executable named program and returns its full path as a string, or #f if not found. On Windows, a program name without an extension is tried with each PATHEXT extension (e.g. \"psql\" finds psql.exe).\n" +
            "Example:\n" +
            "  (which \"ls\") => \"/usr/bin/ls\"\n" +
            "  (which \"nonexistent\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var name = new String(Value.AsString(arguments[0]));
        var candidates = Candidates(name);
        var values = Environment.GetEnvironmentVariable("PATH");
        var paths = values?.Split(Path.PathSeparator);
        if (paths != null)
        {
            foreach (var path in paths)
            {
                if (path.Length == 0) continue;
                foreach (var candidate in candidates)
                {
                    var fullPath = Path.Combine(path, candidate);
                    if (File.Exists(fullPath))
                    {
                        return fullPath.ToCharArray();
                    }
                }
            }
        }
        return Value.F;
    }

    // On Windows a name without an extension is resolved like cmd.exe does:
    // by trying each PATHEXT extension in order (so "psql" finds psql.exe).
    private static List<string> Candidates(string name)
    {
        var result = new List<string>();
        if (!OperatingSystem.IsWindows() || Path.HasExtension(name))
        {
            result.Add(name);
            return result;
        }
        var pathext = Environment.GetEnvironmentVariable("PATHEXT");
        if (string.IsNullOrEmpty(pathext)) pathext = ".COM;.EXE;.BAT;.CMD";
        foreach (var ext in pathext.Split(';'))
        {
            var e = ext.Trim();
            if (e.Length > 0) result.Add(name + e);
        }
        return result;
    }
}
