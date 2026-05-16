namespace scheme;

public class PrimitiveNumless : Primitive
{
    public override string Name()
    {
        return "<";
    }

    public override string Info()
    {
        return
            "Syntax: (< z1 z2 z3 ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if the arguments are monotonically increasing.\n" +
            "Example:\n" +
            "  (< 1 2 3) => #t\n" +
            "  (< 1 1) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, -1);
        if (HasComplex(arguments))
            throw new SchemeError(pos, "<: complex numbers are not ordered");
        object current = arguments[0];
        for (int i = 1; i < arguments.Length; i++)
        {
            object next = arguments[i];
            if (Value.IsInteger(current) && Value.IsInteger(next))
            {
                if (IntegerMath.Compare(current, next) >= 0) return false;
            }
            else if (Value.IsReal(current) && Value.IsReal(next))
            {
                if (Value.AsReal(current) >= Value.AsReal(next)) return false;
            }
            else
            {
                if (MixedNumericCompare(current, next) >= 0) return false;
            }
            current = next;
        }
        return true;
    }
}
