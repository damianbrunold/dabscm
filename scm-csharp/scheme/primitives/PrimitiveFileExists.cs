namespace scheme;

public class PrimitiveFileExists : Primitive
{
    public override string Name()
    {
        return "file-exists?";
    }

    public override string Info()
    {
        return
            "Syntax: (file-exists? filename)\n" +
            "Library: (scheme file)\n" +
            "Description: Returns #t if the named file exists, otherwise returns #f.\n" +
            "Example:\n" +
            "  (file-exists? \"/etc/hosts\") => #t\n" +
            "  (file-exists? \"/nonexistent\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var path = new String(Value.AsString(arguments[0]));
        if (File.Exists(path)) return Value.T;
        return Value.F;
    }
}
