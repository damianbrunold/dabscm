namespace scheme;

public class PrimitiveDictGet : Primitive
{
    public override string Name()
    {
        return "dict-get";
    }

    public override string Info()
    {
        return
            "Syntax: (dict-get d key) (dict-get d key default)\n" +
            "Library: (scm core)\n" +
            "Description: Returns the value associated with key in the dictionary d. If the key is not found and a default is given, returns it; otherwise raises an error.\n" +
            "Example:\n" +
            "  (let ((d (make-dict)))\n" +
            "    (dict-put d \"x\" 42)\n" +
            "    (dict-get d \"x\")) => 42";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
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
            throw new SchemeError(pos, "dict-get: Key must be string or symbol");
        }
        if (arguments.Length == 3 && !dict.ContainsKey(key))
        {
            return arguments[2];
        }
        if (!dict.ContainsKey(key))
        {
            throw new SchemeError(pos, Name() + ": Key ~s not found", key);
        }
        return dict[key];
    }
}
