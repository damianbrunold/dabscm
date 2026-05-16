namespace scheme;

public class PrimitiveSymbolStartsWith : Primitive
{
    public override string Name()
    {
        return "symbol-starts-with?";
    }

    public override string Info()
    {
        return
            "Syntax: (symbol-starts-with? sym str)\n" +
            "Library: (scm string)\n" +
            "Description: Returns #t if the string representation of sym starts with str, #f otherwise. str may be a string or a symbol.\n" +
            "Example:\n" +
            "  (symbol-starts-with? 'foobar \"foo\") => #t\n" +
            "  (symbol-starts-with? 'foobar \"bar\") => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        string str = Value.AsSymbol(arguments[0]);
	string prefix;
        if (Value.IsSymbol(arguments[1]))
        {
            prefix = Value.AsSymbol(arguments[1]);
        }
        else
        {
            prefix = new String(Value.AsString(arguments[1]));
        }
	return str.StartsWith(prefix);
    }
}
