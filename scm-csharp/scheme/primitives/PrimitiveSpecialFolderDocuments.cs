namespace scheme;

public class PrimitiveSpecialFolderDocuments : Primitive
{
    public override string Name()
    {
        return "special-folder-documents";
    }

    public override string Info()
    {
        return
            "Syntax: (special-folder-documents)\n" +
            "Library: (scm system)\n" +
            "Description: Returns the path of the user's documents directory as a string.\n" +
            "Example:\n" +
            "  (special-folder-documents) => \"/home/user/Documents\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        var path = Environment.GetFolderPath(Environment.SpecialFolder.Personal);
        return System.IO.Path.TrimEndingDirectorySeparator(path).ToCharArray();
    }
}
