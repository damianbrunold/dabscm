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
        long n = arguments[0] is long l ? l : -1;
        if (n < 0 || n > 0x10FFFF) throw new SchemeError(pos, "integer->char: not a code point", arguments[0]);
        // characters are UTF-16 code units here: no silent truncation
        if (n > 0xFFFF) throw new SchemeError(pos, "integer->char: characters beyond U+FFFF are not supported", arguments[0]);
        return (char) n;
    }
}
