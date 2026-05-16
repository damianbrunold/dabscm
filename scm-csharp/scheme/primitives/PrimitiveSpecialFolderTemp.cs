namespace scheme;

public class PrimitiveSpecialFolderTemp : Primitive
{
    public override string Name() => "special-folder-temp";
    public override string Info() =>
        "Syntax: (special-folder-temp)\n" +
        "Library: (scm fs)\n" +
        "Description: Returns the platform temp directory path as a string.\n" +
        "Example: (special-folder-temp) => \"/tmp\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return System.IO.Path.TrimEndingDirectorySeparator(System.IO.Path.GetTempPath()).ToCharArray();
    }
}
