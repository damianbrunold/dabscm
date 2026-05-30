namespace scheme;

public class PrimitiveMoveFile : Primitive
{
    public override string Name()
    {
        return "move-file";
    }

    public override string Info()
    {
        return
            "Syntax: (move-file src dest)\n" +
            "Library: (scm fs)\n" +
            "Description: Moves (renames) the file from src to dest, overwriting dest if it exists. Returns unspecified on success, #f on failure.\n" +
            "Example:\n" +
            "  (move-file \"old.txt\" \"new.txt\")";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var src = LongPath.Wlp(new String(Value.AsString(arguments[0])));
        var dst = LongPath.Wlp(new String(Value.AsString(arguments[1])));
        try
        {
            File.Move(src, dst, true);
            return new Values();
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
