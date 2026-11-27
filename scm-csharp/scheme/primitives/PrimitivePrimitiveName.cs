namespace scheme;

// (%primitive-name obj): the name of a primitive procedure as a symbol, #f
// for anything else. (srfi 69)/(srfi 125) recognize the equivalences a
// hash table supports by it: a primitive need not be eq? to itself across
// libraries (in dabscm native it is not).
public class PrimitivePrimitiveName : Primitive
{
    public override string Name() => "%primitive-name";
    public override string Info() => "";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        if (Value.IsPrimitive(arguments[0]))
            return Value.Intern(Value.AsPrimitive(arguments[0]).Name());
        return Value.F;
    }
}
