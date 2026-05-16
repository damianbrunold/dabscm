namespace scheme;

public class PrimitiveAdd : Primitive
{
    public override string Name()
    {
        return "+";
    }

    public override string Info()
    {
        return
            "Syntax: (+ z1 ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the sum of its arguments. With no arguments, returns 0.\n" +
            "Example:\n" +
            "  (+ 3 4) => 7\n" +
            "  (+ 3) => 3\n" +
            "  (+) => 0";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        if (arguments.Length == 0) return 0L;
        if (AllIntegers(arguments))
        {
            object result = arguments[0];
            for (int i = 1; i < arguments.Length; i++)
            {
                result = IntegerMath.GenericAdd(result, arguments[i]);
            }
            return result;
        }
        else if (AllExactNums(arguments))
        {
            object result = arguments[0];
            for (int i = 1; i < arguments.Length; i++)
                result = Rational.Add(result, arguments[i]);
            return result;
        }
        else if (HasComplex(arguments))
        {
            object result = arguments[0];
            for (int i = 1; i < arguments.Length; i++)
                result = Complex.Add(result, arguments[i]);
            return result;
        }
        else
        {
            double result = ToReal(arguments[0]);
            for (int i = 1; i < arguments.Length; i++)
            {
                result += ToReal(arguments[i]);
            }
            return result;
        }
    }
}
