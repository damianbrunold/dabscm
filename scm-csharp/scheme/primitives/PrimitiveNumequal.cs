namespace scheme;

public class PrimitiveNumequal : Primitive
{
    public override string Name()
    {
        return "=";
    }

    public override string Info()
    {
        return
            "Syntax: (= z1 z2 z3 ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if all arguments are numerically equal.\n" +
            "Example:\n" +
            "  (= 1 1 1) => #t\n" +
            "  (= 1 2) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, -1);
        if (HasComplex(arguments))
        {
            for (int i = 1; i < arguments.Length; i++)
            {
                if (!Complex.NumericEquals(arguments[i - 1], arguments[i])) return false;
            }
            return true;
        }
        object current = arguments[0];
        for (int i = 1; i < arguments.Length; i++)
        {
            object next = arguments[i];
            if (Value.IsInteger(current) && Value.IsInteger(next))
            {
                if (!IntegerMath.GenericEquals(current, next)) return false;
            }
            else if (Value.IsReal(current) && Value.IsReal(next))
            {
                if (Value.AsReal(current) != Value.AsReal(next)) return false;
            }
            else
            {
                // Mixed exact/inexact: convert inexact to exact for precise comparison
                if (!MixedNumericEquals(current, next)) return false;
            }
            current = next;
        }
        return true;
    }
}
