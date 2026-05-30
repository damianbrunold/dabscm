namespace scheme;

public class PrimitiveDirectoryExists : Primitive
{
    public override string Name()
    {
        return "directory-exists?";
    }

    public override string Info()
    {
        return
            "Syntax: (directory-exists? dirname)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns #t if the given path names an existing directory, otherwise returns #f.\n" +
            "Example:\n" +
            "  (directory-exists? \"/tmp\") => #t\n" +
            "  (directory-exists? \"/nonexistent\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var path = LongPath.Wlp(new String(Value.AsString(arguments[0])));
        if (Directory.Exists(path)) return Value.T;
        return Value.F;
    }
}
