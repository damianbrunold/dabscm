namespace scheme;

public class PrimitiveSetCurrentDirectory : Primitive
{
    public override string Name() => "set-current-directory!";

    public override string Info() =>
        "Syntax: (set-current-directory! path)\n" +
        "Library: (scm fs)\n" +
        "Description: Sets the current working directory of the process to path. " +
        "Returns the new directory as a string on success, #f on failure.\n" +
        "Example:\n" +
        "  (set-current-directory! \"/tmp\") => \"/tmp\"";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            var path = new String(Value.AsString(arguments[0]));
            Directory.SetCurrentDirectory(path);
            return Directory.GetCurrentDirectory().ToCharArray();
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
