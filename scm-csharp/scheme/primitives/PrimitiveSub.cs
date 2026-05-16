namespace scheme;

public class PrimitiveSub : Primitive
{
    public override string Name()
    {
        return "-";
    }

    public override string Info()
    {
        return
            "Syntax: (- z ...)\n" +
            "Library: (scheme base)\n" +
            "Description: With a single argument, returns the negation of z. With two or more arguments, returns the result of subtracting each successive argument from the first.\n" +
            "Example:\n" +
            "  (- 10 3 2) => 5\n" +
            "  (- 5) => -5";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, -1);
        if (AllIntegers(arguments))
        {
            object result = arguments[0];
            if (arguments.Length == 1)
            {
                result = IntegerMath.GenericNegate(result);
            }
            else
            {
                for (int i = 1; i < arguments.Length; i++)
                    result = IntegerMath.GenericSub(result, arguments[i]);
            }
            return result;
        }
        else if (AllExactNums(arguments))
        {
            if (arguments.Length == 1)
                return Rational.Sub(0L, arguments[0]);
            object result = arguments[0];
            for (int i = 1; i < arguments.Length; i++)
                result = Rational.Sub(result, arguments[i]);
            return result;
        }
        else if (HasComplex(arguments))
        {
            if (arguments.Length == 1)
                return Complex.Negate(arguments[0]);
            object result = arguments[0];
            for (int i = 1; i < arguments.Length; i++)
                result = Complex.Sub(result, arguments[i]);
            return result;
        }
        else
        {
            double result = ToReal(arguments[0]);
            if (arguments.Length == 1)
            {
                result = -result;
            }
            else
            {
                for (int i = 1; i < arguments.Length; i++)
                    result -= ToReal(arguments[i]);
            }
            return result;
        }
    }
}
