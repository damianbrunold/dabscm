namespace scheme;

public class PrimitiveStringFoldcase : Primitive
{
    public override string Name() => "string-foldcase";

    public override string Info()
    {
        return
            "Syntax: (string-foldcase s)\n" +
            "Library: (scheme char)\n" +
            "Description: Returns a string that is the result of applying Unicode case folding to s, which lowercases the string in a locale-independent manner.\n" +
            "Example:\n" +
            "  (string-foldcase \"Hello\") => \"hello\"\n" +
            "  (string-foldcase \"SCHEME\") => \"scheme\"";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        return UnicodeCaseMap.ToFold(new string(Value.AsString(arguments[0]))).ToCharArray();
    }
}
