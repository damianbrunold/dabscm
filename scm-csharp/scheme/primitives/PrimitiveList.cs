namespace scheme;

public class PrimitiveList : Primitive
{
    public override string Name()
    {
        return "list";
    }

    public override string Info()
    {
        return
            "Syntax: (list obj ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns a newly allocated list of its arguments.\n" +
            "Example:\n" +
            "  (list 'a (+ 3 4) 'c) => (a 7 c)\n" +
            "  (list) => ()";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        object result = Value.NIL;
        for (int i = arguments.Length - 1; i >= 0; i--)
            result = new Pair(arguments[i], result);
        return result;
    }
}
