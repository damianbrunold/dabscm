namespace scheme;

public class PrimitiveBaseName : Primitive
{
    public override string Name()
    {
        return "base-name";
    }

    public override string Info()
    {
        return
            "Syntax: (base-name path)\n" +
            "Library: (scm system)\n" +
            "Description: Returns the file name (including extension) from the given path string, without the directory part.\n" +
            "Example:\n" +
            "  (base-name \"/usr/share/doc/readme.txt\") => \"readme.txt\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var path = new String(Value.AsString(arguments[0]));
        return Path.GetFileName(path).ToCharArray();
    }
}
