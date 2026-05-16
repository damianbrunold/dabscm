namespace scheme;

public class PrimitiveVector : Primitive
{
    public override string Name()
    {
        return "vector";
    }

    public override string Info()
    {
        return
            "Syntax: (vector obj ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns a newly allocated vector whose elements contain the given arguments.\n" +
            "Example:\n" +
            "  (vector 1 2 3) => #(1 2 3)\n" +
            "  (vector 'a 'b 'c) => #(a b c)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        var result = new object[arguments.Length];
        Array.Copy(arguments, result, arguments.Length);
        return result;
    }
}
