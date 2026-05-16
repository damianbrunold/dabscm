namespace scheme;

public class PrimitiveOpenJsonString : Primitive
{
    public override string Name()
    {
        return "open-json-string";
    }

    public override string Info()
    {
        return
            "Syntax: (open-json-string s)\n" +
            "Library: (scm json)\n" +
            "Description: Returns a JSON reader object that parses the JSON contained in the string s. An optional list-id symbol or string may be specified to identify list nodes.\n" +
            "Example:\n" +
            "  (define r (open-json-string \"{\\\"a\\\": 1}\"))\n" +
            "  (json-next-object r) => parsed object";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        string text = new String(Value.AsString(arguments[0]));
        var parser = new JsonParser(new StringReader(text));
        if (arguments.Length == 2)
        {
            if (Value.IsSymbol(arguments[1]))
            {
                parser.WithListId(Value.AsSymbol(arguments[1]));
            }
            else
            {
                parser.WithListId(new String(Value.AsString(arguments[1])));
            }
        }
        return new NativeValue(parser);
    }
}
