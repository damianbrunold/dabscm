namespace scheme;

public class PrimitiveSpecialFolderUserHome : Primitive
{
    public override string Name()
    {
        return "special-folder-user-home";
    }

    public override string Info()
    {
        return
            "Syntax: (special-folder-user-home)\n" +
            "Library: (scm fs)\n" +
            "Description: Returns the path of the user home directory as a string.\n" +
            "Example:\n" +
            "  (special-folder-user-home) => \"/home/user\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        var path = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        return System.IO.Path.TrimEndingDirectorySeparator(path).ToCharArray();
    }
}
