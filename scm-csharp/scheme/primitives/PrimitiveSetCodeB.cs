namespace scheme;

public class PrimitiveSetCodeB : Primitive
{
    public override string Name()
    {
        return "set-code!";
    }

    public override string Info()
    {
        return
            "Syntax: (set-code! fn instructions)\n" +
            "Library: (scm compile)\n" +
            "Description: Replaces the bytecode instructions of the lambda fn with the given instructions list. Used for low-level code patching.\n" +
            "Example:\n" +
            "  (define f (lambda (x) x))\n" +
            "  (set-code! f (get-code f))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        Lambda fn = Value.AsLambda(arguments[0]);
        fn.code = (List<Instruction>) arguments[1];
        return new Values();
    }
}
