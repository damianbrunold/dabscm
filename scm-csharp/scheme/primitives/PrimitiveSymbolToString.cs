namespace scheme;

public class PrimitiveSymbolToString : Primitive
{
    public override string Name()
    {
        return "symbol->string";
    }

    public override string Info()
    {
        return
            "Syntax: (symbol->string sym)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns the name of sym as a string.\n" +
            "Example:\n" +
            "  (symbol->string 'hello) => \"hello\"\n" +
            "  (symbol->string 'foo-bar) => \"foo-bar\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.AsSymbol(arguments[0]).ToCharArray();
    }
}
