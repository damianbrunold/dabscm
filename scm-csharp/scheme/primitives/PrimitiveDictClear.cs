namespace scheme;

public class PrimitiveDictClear : Primitive
{
    public override string Name()
    {
        return "dict-clear";
    }

    public override string Info()
    {
        return
            "Syntax: (dict-clear d)\n" +
            "Library: (scm core)\n" +
            "Description: Removes all key-value associations from the dictionary d, leaving it empty.\n" +
            "Example:\n" +
            "  (let ((d (make-dict)))\n" +
            "    (dict-put d \"key\" 1)\n" +
            "    (dict-clear d)\n" +
            "    (dict-size d)) => 0";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        Value.AsDict(arguments[0]).Clear();
        return new Values();
    }
}
