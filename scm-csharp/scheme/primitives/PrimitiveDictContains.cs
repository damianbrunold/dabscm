namespace scheme;

public class PrimitiveDictContains : Primitive
{
    public override string Name()
    {
        return "dict-contains";
    }

    public override string Info()
    {
        return
            "Syntax: (dict-contains d key)\n" +
            "Library: (scm core)\n" +
            "Description: Returns #t if the dictionary d contains an entry for key (a string or symbol), otherwise returns #f.\n" +
            "Example:\n" +
            "  (let ((d (make-dict)))\n" +
            "    (dict-put d \"x\" 42)\n" +
            "    (dict-contains d \"x\")) => #t";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var dict = Value.AsDict(arguments[0]);
        string key;
        if (Value.IsString(arguments[1]))
        {
            key = new String(Value.AsString(arguments[1]));
        }
        else if (Value.IsSymbol(arguments[1]))
        {
            key = Value.AsSymbol(arguments[1]);
        }
        else
        {
            throw new SchemeError(pos, Name() + ": Key must be string or symbol");
        }
        return dict.ContainsKey(key);
    }
}
