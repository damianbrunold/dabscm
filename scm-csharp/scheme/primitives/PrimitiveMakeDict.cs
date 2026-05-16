namespace scheme;

public class PrimitiveMakeDict : Primitive
{
    public override string Name()
    {
        return "make-dict";
    }

    public override string Info()
    {
        return
            "Syntax: (make-dict)\n" +
            "Library: (scm core)\n" +
            "Description: Returns a new empty mutable dictionary (hash map) with string or symbol keys.\n" +
            "Example:\n" +
            "  (let ((d (make-dict)))\n" +
            "    (dict-put d \"key\" 42)\n" +
            "    (dict-get d \"key\")) => 42";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        return new Dictionary<string, object>();
    }
}
