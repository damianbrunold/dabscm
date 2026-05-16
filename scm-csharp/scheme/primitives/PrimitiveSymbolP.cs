namespace scheme;

public class PrimitiveSymbolP : Primitive
{
    public override string Name()
    {
        return "symbol?";
    }

    public override string Info()
    {
        return
            "Syntax: (symbol? obj)\n" +
            "Library: (scheme base)\n" +
            "Description: Returns #t if obj is a symbol, #f otherwise.\n" +
            "Example:\n" +
            "  (symbol? 'foo) => #t\n" +
            "  (symbol? \"foo\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return Value.IsSymbol(arguments[0]);
    }
}
