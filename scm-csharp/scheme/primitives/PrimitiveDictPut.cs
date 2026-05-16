namespace scheme;

public class PrimitiveDictPut : Primitive
{
    public override string Name()
    {
        return "dict-put";
    }

    public override string Info()
    {
        return
            "Syntax: (dict-put d key value)\n" +
            "Library: (scm core)\n" +
            "Description: Associates key (a string or symbol) with value in the dictionary d. If the key already exists, the old value is replaced.\n" +
            "Example:\n" +
            "  (let ((d (make-dict)))\n" +
            "    (dict-put d \"x\" 42)\n" +
            "    (dict-get d \"x\")) => 42";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 3, 3);
        Dictionary<string, object> dict = Value.AsDict(arguments[0]);
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
        dict[key] = arguments[2];
        return new Values();
    }
}
