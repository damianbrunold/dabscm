namespace scheme;

public class PrimitiveCharToInteger : Primitive
{
    public override string Name()
    {
        return "char->integer";
    }

    public override string Info()
    {
        return
            "Syntax: (char->integer char)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the Unicode scalar value (codepoint) of the given character as an exact integer.\n" +
            "Example:\n" +
            "  (char->integer #\\a) => 97\n" +
            "  (char->integer #\\A) => 65";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return (long) Value.AsChar(arguments[0]);
    }
}
