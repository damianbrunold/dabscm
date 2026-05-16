namespace scheme;

public class PrimitiveMemq : Primitive
{
    public override string Name()
    {
        return "memq";
    }

    public override string Info()
    {
        return
            "Syntax: (memq obj list)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the first sublist of list whose car is eq? to obj, or #f if no such sublist exists.\n" +
            "Example:\n" +
            "  (memq 'b '(a b c)) => (b c)\n" +
            "  (memq 'z '(a b c)) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var val = arguments[0];
        var lst = arguments[1];
        while (lst != Value.NIL)
        {
            if (!Value.IsPair(lst)) return Value.F;
            if (val.Equals(Value.AsPair(lst).car)) return lst;
            lst = Value.AsPair(lst).cdr;
        }
        return Value.F;
    }
}
