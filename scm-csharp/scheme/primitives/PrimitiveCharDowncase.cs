using System.Globalization;

namespace scheme;

public class PrimitiveCharDowncase : Primitive
{
    public override string Name()
    {
        return "char-downcase";
    }

    public override string Info()
    {
        return
            "Syntax: (char-downcase char)\n" +
            "Library: (scheme char)\n" +
            "Description: Returns the lowercase equivalent of char if it exists, otherwise returns char.\n" +
            "Example:\n" +
            "  (char-downcase #\\A) => #\\a\n" +
            "  (char-downcase #\\a) => #\\a";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Char.ToLower(Value.AsChar(arguments[0]), CultureInfo.InvariantCulture);
    }
}
