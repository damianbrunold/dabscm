namespace scheme;

public class PrimitiveLambdaP : Primitive
{
    public override string Name()
    {
        return "lambda?";
    }

    public override string Info()
    {
        return
            "Syntax: (lambda? obj)\n" +
            "Library: (scm core)\n" +
            "Description: Returns #t if obj is a compiled lambda (procedure), otherwise returns #f.\n" +
            "Example:\n" +
            "  (lambda? (lambda (x) x)) => #t\n" +
            "  (lambda? 42) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsLambda(arguments[0]);
    }
}
