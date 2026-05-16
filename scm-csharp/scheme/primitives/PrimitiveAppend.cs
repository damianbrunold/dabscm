namespace scheme;

public class PrimitiveAppend : Primitive
{
    public override string Name()
    {
        return "append";
    }

    public override string Info()
    {
        return
            "Syntax: (append list1 ... obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns a list consisting of the elements of the first list followed by the elements of the other lists. The last argument may be any object.\n" +
            "Example:\n" +
            "  (append '(x) '(y)) => (x y)\n" +
            "  (append '(a) '(b c d)) => (a b c d)\n" +
            "  (append '(a b) '() '(c)) => (a b c)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        if (arguments.Length == 0) return Value.NIL;
        List<object> result = new();
        for (int i = 0; i < arguments.Length - 1; i++)
        {
            object pair = arguments[i];
            while (pair != Value.NIL)
            {
                result.Add(Value.AsPair(pair).car);
                pair = Value.AsPair(pair).cdr;
            }
        }
        if (result.Count == 0)
        {
            return arguments[arguments.Length - 1];
        }
        else
        {
            Pair list = (Pair)Pair.List(result.ToArray());
            Pair last = list;
            while (last.cdr != Value.NIL) last = Value.AsPair(last.cdr);
            last.cdr = arguments[arguments.Length - 1];
            return list;
        }
    }
}
