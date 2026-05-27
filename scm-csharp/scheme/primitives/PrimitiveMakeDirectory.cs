namespace scheme;

public class PrimitiveMakeDirectory : Primitive
{
    public override string Name()
    {
        return "make-directory";
    }

    public override string Info()
    {
        return
            "Syntax: (make-directory path)\n" +
            "Library: (scm fs)\n" +
            "Description: Creates the directory named by path, including all intermediate directories.\n" +
            "Example:\n" +
            "  (make-directory \"/tmp/new/dir\")";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var path = new String(Value.AsString(arguments[0]));
        Directory.CreateDirectory(path);
        return new Values();
    }
}
