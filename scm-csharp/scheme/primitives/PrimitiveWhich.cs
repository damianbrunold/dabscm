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
            "Library: (scm system)\n" +
            "Description: Searches the directories in PATH for an executable named program and returns its full path as a string, or #f if not found.\n" +
            "Example:\n" +
            "  (which \"ls\") => \"/usr/bin/ls\"\n" +
            "  (which \"nonexistent\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var name = new String(Value.AsString(arguments[0]));
        var values = Environment.GetEnvironmentVariable("PATH");
        var paths = values?.Split(Path.PathSeparator);
        if (paths != null)
        {
            foreach (var path in paths)
            {
                var fullPath = Path.Combine(path, name);
                if (File.Exists(fullPath))
                {
                    return fullPath.ToCharArray();
                }
            }
        }
        return Value.F;
    }
}
