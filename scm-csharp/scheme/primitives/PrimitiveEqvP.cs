namespace scheme;

public class PrimitiveEqvP : Primitive
{
    public override string Name()
    {
        return "eqv?";
    }

    public override string Info()
    {
        return
            "Syntax: (eqv? obj1 obj2)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj1 and obj2 are operationally equivalent. Numbers are eqv? if they have the same exactness and are numerically equal.\n" +
            "Example:\n" +
            "  (eqv? 'a 'a) => #t\n" +
            "  (eqv? 1 1) => #t\n" +
            "  (eqv? 1 1.0) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        return Eqv(arguments[0], arguments[1]);
    }

    //(define (eqv? x y)
    //  (cond
    //   ((eq? x y))
    //   ((number? x)
    //    (and (number? y)
    //         (if (exact? x)
    //             (and (exact? y) (= x y))
    //	           (and (inexact? y) (= x y)))))
    //   ((char? x) (and (char? y) (char=? x y)))
    //   (else #f)))
    
    public static bool Eqv(object a, object b)
    {
        if (PrimitiveEqP.Eq(a, b))
        {
            return true;
        }
        
        if (Value.IsInteger(a) && Value.IsInteger(b))
        {
            return IntegerMath.GenericEquals(a, b);
        }
        
        if (Value.IsRational(a) && Value.IsRational(b))
        {
            return Value.AsRational(a).Equals(Value.AsRational(b));
        }

        if (Value.IsComplex(a) && Value.IsComplex(b))
        {
            return Value.AsComplex(a).Equals(Value.AsComplex(b));
        }

        if (Value.IsReal(a) && Value.IsReal(b))
        {
            return Value.AsReal(a).Equals(Value.AsReal(b));
        }

        if (Value.IsChar(a) && Value.IsChar(b))
        {
            return Value.AsChar(a).Equals(Value.AsChar(b));
        }

        return false;
    }
}
