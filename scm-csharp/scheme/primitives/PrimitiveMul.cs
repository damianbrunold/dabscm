namespace scheme;

public class PrimitiveMul : Primitive
{
    public override string Name()
    {
        return "*";
    }

    public override string Info()
    {
        return
            "Syntax: (* z1 ...)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the product of its arguments. With no arguments, returns 1.\n" +
            "Example:\n" +
            "  (* 4 5) => 20\n" +
            "  (* 3) => 3\n" +
            "  (*) => 1";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        if (arguments.Length == 0) return 1L;
        if (AllIntegers(arguments))
        {
            object result = arguments[0];
            for (int i = 1; i < arguments.Length; i++)
            {
                result = IntegerMath.GenericMul(result, arguments[i]);
            }
            return result;
        }
        else if (AllExactNums(arguments))
        {
            object result = arguments[0];
            for (int i = 1; i < arguments.Length; i++)
                result = Rational.Mul(result, arguments[i]);
            return result;
        }
        else if (HasComplex(arguments))
        {
            object result = arguments[0];
            for (int i = 1; i < arguments.Length; i++)
                result = Complex.Mul(result, arguments[i]);
            return result;
        }
        else
        {
            double result = ToReal(arguments[0]);
            for (int i = 1; i < arguments.Length; i++)
            {
                result *= ToReal(arguments[i]);
            }
            return result;
        }
    }
}
