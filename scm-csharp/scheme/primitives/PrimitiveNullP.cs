namespace scheme;

public class PrimitiveNullP : Primitive
{
    public override string Name()
    {
        return "null?";
    }

    public override string Info()
    {
        return
            "Syntax: (null? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is the empty list '(), otherwise returns #f.\n" +
            "Example:\n" +
            "  (null? '()) => #t\n" +
            "  (null? '(1 2)) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return arguments[0] == Value.NIL;
    }
}
