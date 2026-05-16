namespace scheme;

public class PrimitiveMakeVector : Primitive
{
    public override string Name()
    {
        return "make-vector";
    }

    public override string Info()
    {
        return
            "Syntax: (make-vector k) (make-vector k fill)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns a newly allocated vector of k elements. If fill is given, every element is initialized to fill; otherwise each element is 0.\n" +
            "Example:\n" +
            "  (make-vector 3 0) => #(0 0 0)\n" +
            "  (make-vector 3 'a) => #(a a a)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        int n = IntegerMath.ToInt(arguments[0]);
        object obj = 0;
        if (arguments.Length == 2) obj = arguments[1];

        var result = new object[n];
        Array.Fill(result, obj);
        return result;
    }
}
