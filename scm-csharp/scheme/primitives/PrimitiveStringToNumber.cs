using System.Globalization;

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
        string s = new String(Value.AsString(arguments[0]));
        int radix = 10;
        if (arguments.Length == 2)
        {
            radix = IntegerMath.ToInt(arguments[1]);
            if (radix != 2 && radix != 8 && radix != 10 && radix != 16)
                throw new SchemeError(pos, "string->number: bad radix", arguments[1]);
        }
        return Parse(s, radix);
    }

    /// <summary>
    /// The number s denotes as the reader reads it (prefixes, rationals,
    /// decimals, complex numbers), else #f: the whole string, without
    /// surrounding whitespace. radix applies unless s has a radix prefix.
    /// </summary>
    public static object Parse(string s, int radix)
    {
        if (s.Length == 0 || char.IsWhiteSpace(s[0])) return Value.F;
        bool radixPrefix = false;
        int i = 0;
        while (i + 1 < s.Length && s[i] == '#')
        {
            char p = char.ToLowerInvariant(s[i + 1]);
            if (p == 'x' || p == 'b' || p == 'o' || p == 'd') radixPrefix = true;
            else if (p != 'e' && p != 'i') return Value.F;
            i += 2;
        }
        string text = s;
        if (!radixPrefix && radix != 10)
            text = (radix == 16 ? "#x" : radix == 8 ? "#o" : "#b") + s;
        try
        {
            var reader = new TextStream(new StringReader(text), "string->number");
            Token? token = Tokenizer.ReadToken(reader);
            if (token == null || reader.Peek() != -1) return Value.F;
            object? n = PrimitiveRead.NumberFromToken(token);
            return n ?? Value.F;
        }
        catch (Exception)
        {
            return Value.F;
        }
    }
}
