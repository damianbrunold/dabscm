namespace scheme;

public class PrimitiveMoveDirectory : Primitive
{
    public override string Name()
    {
        return "move-directory";
    }

    public override string Info()
    {
        return
            "Syntax: (move-directory src dest)\n" +
            "Library: (scm fs)\n" +
            "Description: Moves (renames) the directory from src to dest. Returns unspecified on success, #f on failure.\n" +
            "Example:\n" +
            "  (move-directory \"/tmp/old\" \"/tmp/new\")";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var src = new String(Value.AsString(arguments[0]));
        var dst = new String(Value.AsString(arguments[1]));
        try
        {
            Directory.Move(src, dst);
            return new Values();
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
