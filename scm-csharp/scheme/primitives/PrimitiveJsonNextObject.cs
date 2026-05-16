namespace scheme;

public class PrimitiveJsonNextObject : Primitive
{
    public override string Name()
    {
        return "json-next-object";
    }

    public override string Info()
    {
        return
            "Syntax: (json-next-object reader)\n" +
            "Library: (scm core)\n" +
            "Description: Reads and returns the next JSON object from the given JSON reader, or #f if there are no more objects.\n" +
            "Example:\n" +
            "  (let ((r (open-json-file \"data.json\")))\n" +
            "    (json-next-object r))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            JsonParser reader = (JsonParser) Value.AsNativeValue(arguments[0]).value;
            var result = reader.NextObject();
            if (result == null) return Value.F;
            return new NativeValue(result);
        }
        catch (Exception)
        {
            throw new SchemeError(pos, "json-next-object failed");
        }
    }
}
