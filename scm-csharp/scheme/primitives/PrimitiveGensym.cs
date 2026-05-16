namespace scheme;

public class PrimitiveGensym : Primitive
{
    private static int counter = 1;

    public override string Name()
    {
        return "gensym";
    }

    public override string Info()
    {
        return
            "Syntax: (gensym)\n" +
            "Library: (scm core)\n" +
            "Description: Returns a fresh, unique, non-interned symbol. Each call returns a symbol distinct from all previously generated symbols.\n" +
            "Example:\n" +
            "  (gensym) => gensym-1\n" +
            "  (eq? (gensym) (gensym)) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 0, 0);
        // do not intern the symbol to ensure unique symbol!
        return "gensym-" + counter++;
    }
}
