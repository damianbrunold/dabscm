namespace scheme;

public class PrimitiveDictKeys : Primitive
{
    public override string Name()
    {
        return "dict-keys";
    }

    public override string Info()
    {
        return
            "Syntax: (dict-keys d)\n" +
            "Library: (scm core)\n" +
            "Description: Returns a list of all keys (as strings) in the dictionary d.\n" +
            "Example:\n" +
            "  (let ((d (make-dict)))\n" +
            "    (dict-put d \"a\" 1)\n" +
            "    (dict-put d \"b\" 2)\n" +
            "    (dict-keys d)) => (\"a\" \"b\")";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        Dictionary<string, object> dict = Value.AsDict(arguments[0]);
        List<char[]> keys = new();
        foreach (string key in dict.Keys)
        {
            keys.Add(key.ToCharArray());
        }
        return Pair.List(keys.ToArray());
    }
}
