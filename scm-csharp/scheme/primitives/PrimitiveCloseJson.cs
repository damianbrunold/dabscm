namespace scheme;

public class PrimitiveCloseJson : Primitive
{
    public override string Name()
    {
        return "close-json";
    }

    public override string Info()
    {
        return
            "Syntax: (close-json reader)\n" +
            "Library: (scm core)\n" +
            "Description: Closes the given JSON reader, releasing any underlying resources.\n" +
            "Example:\n" +
            "  (let ((r (open-json-file \"data.json\")))\n" +
            "    (close-json r))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            JsonParser reader = (JsonParser) Value.AsNativeValue(arguments[0]).value;
            reader.Close();
            return new Values();
        }
        catch (Exception)
        {
            throw new SchemeError(pos, "close-json failed");
        }
    }
}
