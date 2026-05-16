namespace scheme;

public class PrimitiveDictSize : Primitive
{
    public override string Name()
    {
        return "dict-size";
    }

    public override string Info()
    {
        return
            "Syntax: (dict-size d)\n" +
            "Library: (scm core)\n" +
            "Description: Returns the number of key-value entries in the dictionary d.\n" +
            "Example:\n" +
            "  (let ((d (make-dict)))\n" +
            "    (dict-put d \"a\" 1)\n" +
            "    (dict-size d)) => 1";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return (long) Value.AsDict(arguments[0]).Count;
    }
}
