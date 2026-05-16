namespace scheme;

public class PrimitiveCurrentDirectory : Primitive
{
    public override string Name()
    {
        return "current-directory";
    }

    public override string Info()
    {
        return
            "Syntax: (current-directory)\n" +
            "Library: (scm system)\n" +
            "Description: Returns the current working directory as a string.\n" +
            "Example:\n" +
            "  (current-directory) => \"/home/user/projects\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return Directory.GetCurrentDirectory().ToCharArray();
    }
}
