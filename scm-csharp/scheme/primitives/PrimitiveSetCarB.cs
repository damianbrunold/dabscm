namespace scheme;

public class PrimitiveSetCarB : Primitive
{
    public override string Name()
    {
        return "set-car!";
    }

    public override string Info()
    {
        return
            "Syntax: (set-car! pair obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Stores obj in the car field of pair. It is an error if pair is not a pair.\n" +
            "Example:\n" +
            "  (define p (list 1 2 3))\n" +
            "  (set-car! p 'a)\n" +
            "  p => (a 2 3)";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        Value.AsPair(arguments[0]).car = arguments[1];
        return new Values();
    }
}
