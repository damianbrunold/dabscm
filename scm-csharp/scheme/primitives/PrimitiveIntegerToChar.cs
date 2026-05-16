namespace scheme;

public class PrimitiveIntegerToChar : Primitive
{
    public override string Name()
    {
        return "integer->char";
    }

    public override string Info()
    {
        return
            "Syntax: (integer->char n)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the character corresponding to the given Unicode scalar value (codepoint).\n" +
            "Example:\n" +
            "  (integer->char 97) => #\\a\n" +
            "  (integer->char 65) => #\\A";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return (char) IntegerMath.ToLong(arguments[0]);
    }
}
