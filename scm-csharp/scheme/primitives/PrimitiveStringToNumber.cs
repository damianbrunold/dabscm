using System.Globalization;
using System.Numerics;

namespace scheme;

public class PrimitiveStringToNumber : Primitive
{
    public override string Name()
    {
        return "string->number";
    }

    public override string Info()
    {
        return
            "Syntax: (string->number s radix?)\n" +
            "Library: (scheme base)\n" +
            "Description: Converts the string s to a number using the given radix (default 10). Returns #f if s cannot be parsed as a number.\n" +
            "Example:\n" +
            "  (string->number \"42\") => 42\n" +
            "  (string->number \"ff\" 16) => 255\n" +
            "  (string->number \"abc\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        // TODO: Complex number parsing will be handled by the tokenizer
        string s = new String(Value.AsString(arguments[0]));
        bool exact = s.IndexOf('.') == -1;
        int numbase = 10;
        if (arguments.Length == 2) numbase = IntegerMath.ToInt(arguments[1]);
        while (s.StartsWith("#"))
        {
            if (s.StartsWith("#e"))
            {
                exact = true;
                s = s.Substring(2);
            }
            else if (s.StartsWith("#i"))
            {
                exact = false;
                s = s.Substring(2);
            }
            else if (s.StartsWith("#x"))
            {
                numbase = 16;
                s = s.Substring(2);
            }
            else if (s.StartsWith("#b"))
            {
                numbase = 2;
                s = s.Substring(2);
            }
            else if (s.StartsWith("#o"))
            {
                numbase = 8;
                s = s.Substring(2);
            }
            else
            {
                break;
            }
        }
        if (exact && numbase == 10 && s.IndexOfAny("eEsSfFdDlL".ToCharArray()) >= 0)
            exact = false;
        try
        {
            if (exact)
            {
                int slash = s.IndexOf('/');
                if (slash >= 0)
                {
                    string ns = s.Substring(0, slash), ds = s.Substring(slash + 1);
                    object n = ParseIntegerInRadix(ns, numbase);
                    object d = ParseIntegerInRadix(ds, numbase);
                    return Rational.Create(n, d);
                }
                return ParseIntegerInRadix(s, numbase);
            }
            else
            {
                // Normalize R7RS exponent markers (s, f, d, l) to 'e'
                foreach (char em in "sfdlSFDL")
                    s = s.Replace(em, 'e');
                return double.Parse(s, CultureInfo.InvariantCulture);
            }
        }
        catch (Exception)
        {
            return Value.F;
        }
    }

    private static object ParseIntegerInRadix(string s, int numbase)
    {
        if (numbase == 10)
        {
            if (long.TryParse(s, CultureInfo.InvariantCulture, out long lv)) return lv;
            return BigInteger.Parse(s, CultureInfo.InvariantCulture);
        }
        // For non-decimal bases, try long first via Convert
        bool negative = s.StartsWith("-");
        string digits = negative ? s.Substring(1) : s;
        try
        {
            long val = Convert.ToInt64(digits, numbase);
            return negative ? IntegerMath.Negate(val) : (object)val;
        }
        catch (OverflowException)
        {
            // Parse as BigInteger for non-decimal
            BigInteger val = BigInteger.Zero;
            foreach (char c in digits)
            {
                int d = c >= '0' && c <= '9' ? c - '0' :
                        c >= 'a' && c <= 'f' ? c - 'a' + 10 :
                        c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
                if (d < 0) throw new FormatException();
                val = val * numbase + d;
            }
            if (negative) val = -val;
            return IntegerMath.Normalize(val);
        }
    }
}
