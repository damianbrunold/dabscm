namespace scheme;

public class PrimitiveGenerateTemporaries : Primitive
{
    private static int counter = 1;

    public override string Name()
    {
        return "generate-temporaries";
    }

    public override string Info()
    {
        return
            "Syntax: (generate-temporaries list)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns a list of fresh identifiers (syntax objects wrapping unique symbols), " +
            "one for each element of list. The identifiers are guaranteed to be distinct from all " +
            "other identifiers. Used in syntax-case transformers for hygienic macro expansion.\n" +
            "Example:\n" +
            "  (length (generate-temporaries '(a b c))) => 3";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        object lst = arguments[0];
        // Count elements
        object result = Value.NIL;
        Pair? tail = null;
        while (lst != Value.NIL && Value.IsPair(lst))
        {
            string name = "tmp-" + counter++;
            // Create as a SyntaxObject with a unique scope (fresh identifier)
            int scope = ScopeSet.FreshScope();
            object id = new SyntaxObject(name, ScopeSet.Of(scope), pos);
            Pair cell = new Pair(id, Value.NIL);
            if (tail == null) { result = cell; tail = cell; }
            else { tail.cdr = cell; tail = cell; }
            lst = Value.AsPair(lst).cdr;
        }
        return result;
    }
}
