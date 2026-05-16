using System.Globalization;

namespace scheme;

public class PrimitiveCharUpcase : Primitive
{
    public override string Name()
    {
        return "char-upcase";
    }

    public override string Info()
    {
        return
            "Syntax: (char-upcase char)\n" +
            "Library: (scheme char)\n" +
            "Description: Returns the uppercase equivalent of char if it exists, otherwise returns char.\n" +
            "Example:\n" +
            "  (char-upcase #\\a) => #\\A\n" +
            "  (char-upcase #\\A) => #\\A";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Char.ToUpper(Value.AsChar(arguments[0]), CultureInfo.InvariantCulture);
    }
}
