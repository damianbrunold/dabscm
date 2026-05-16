namespace scheme;

public class PrimitiveDiv : Primitive
{
    public override string Name()
    {
        return "/";
    }

    public override string Info()
    {
        return
            "Syntax: (/ z1 z2 ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the quotient of dividing z1 by the remaining arguments. With one argument, returns the multiplicative inverse 1/z1.\n" +
            "Example:\n" +
            "  (/ 10 2) => 5\n" +
            "  (/ 10 2 5) => 1\n" +
            "  (/ 4) => 1/4";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, -1);
        if (AllExactNums(arguments))
        {
            if (arguments.Length == 1)
            {
                // (/ x) = 1/x
                if (Value.IsInteger(arguments[0]))
                {
                    if (IntegerMath.IsZero(arguments[0])) throw new SchemeError(pos, "/: Division by zero");
                    return Rational.Create(1L, arguments[0]);
                }
                else
                {
                    var r = Value.AsRational(arguments[0]);
                    return Rational.Create(r.Denominator, r.Numerator);
                }
            }
            object result = arguments[0];
            for (int i = 1; i < arguments.Length; i++)
            {
                if (Value.IsInteger(arguments[i]) && IntegerMath.IsZero(arguments[i]))
                    throw new SchemeError(pos, "/: Division by zero");
                if (Value.IsRational(arguments[i]) && IntegerMath.IsZero(Value.AsRational(arguments[i]).Numerator))
                    throw new SchemeError(pos, "/: Division by zero");
                result = Rational.Div(result, arguments[i]);
            }
            return result;
        }
        else if (HasComplex(arguments))
        {
            if (arguments.Length == 1)
                return Complex.Div(1L, arguments[0]);
            object result = arguments[0];
            for (int i = 1; i < arguments.Length; i++)
                result = Complex.Div(result, arguments[i]);
            return result;
        }
        else
        {
            if (arguments.Length == 1)
            {
                double value = ToReal(arguments[0]);
                if (value == 0.0) throw new SchemeError(pos, "/: Division by ~s", value);
                return 1.0 / value;
            }
            double dresult = ToReal(arguments[0]);
            for (int i = 1; i < arguments.Length; i++)
            {
                double value = ToReal(arguments[i]);
                if (value == 0.0) throw new SchemeError(pos, "/: Division by ~s", value);
                dresult /= value;
            }
            return dresult;
        }
    }
}
