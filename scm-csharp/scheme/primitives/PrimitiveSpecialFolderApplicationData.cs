namespace scheme;

public class PrimitiveSpecialFolderApplicationData : Primitive
{
    public override string Name()
    {
        return "special-folder-application-data";
    }

    public override string Info()
    {
        return
            "Syntax: (special-folder-application-data)\n" +
            "Library: (scm system)\n" +
            "Description: Returns the path of the user's application data directory as a string.\n" +
            "Example:\n" +
            "  (special-folder-application-data) => \"/home/user/.config\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        var path = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        return System.IO.Path.TrimEndingDirectorySeparator(path).ToCharArray();
    }
}
