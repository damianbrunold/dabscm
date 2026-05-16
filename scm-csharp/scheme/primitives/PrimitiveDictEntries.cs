namespace scheme;

public class PrimitiveDictEntries : Primitive
{
    public override string Name()
    {
        return "dict-entries";
    }

    public override string Info()
    {
        return
            "Syntax: (dict-entries d)\n" +
            "Library: (scm core)\n" +
            "Description: Returns a list of (key . value) pairs for all entries in the dictionary d.\n" +
            "Example:\n" +
            "  (let ((d (make-dict)))\n" +
            "    (dict-put d \"a\" 1)\n" +
            "    (dict-entries d)) => ((\"a\" . 1))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        Dictionary<string, object> dict = Value.AsDict(arguments[0]);
        List<object> keys = new();
        foreach (string key in dict.Keys)
        {
            keys.Add(new Pair(key.ToCharArray(), dict[key]));
        }
        return Pair.List(keys.ToArray());
    }
}
