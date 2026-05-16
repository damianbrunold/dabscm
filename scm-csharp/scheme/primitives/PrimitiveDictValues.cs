namespace scheme;

public class PrimitiveDictValues : Primitive
{
    public override string Name()
    {
        return "dict-values";
    }

    public override string Info()
    {
        return
            "Syntax: (dict-values d)\n" +
            "Library: (scm core)\n" +
            "Description: Returns a list of all values in the dictionary d.\n" +
            "Example:\n" +
            "  (let ((d (make-dict)))\n" +
            "    (dict-put d \"a\" 1)\n" +
            "    (dict-values d)) => (1)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        Dictionary<string, object> dict = Value.AsDict(arguments[0]);
        List<object> values = new();
        foreach (object value in dict.Values)
        {
            values.Add(value);
        }
        return Pair.List(values.ToArray());
    }
}
