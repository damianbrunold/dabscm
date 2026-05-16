namespace scheme;

public class PrimitiveCloseInputZip : Primitive
{
    public override string Name()
    {
        return "close-input-zip";
    }

    public override string Info()
    {
        return
            "Syntax: (close-input-zip zip)\n" +
            "Library: (scm zip)\n" +
            "Description: Closes the given ZIP input archive, releasing all underlying resources.\n" +
            "Example:\n" +
            "  (let ((z (open-input-zip-file \"archive.zip\")))\n" +
            "    (close-input-zip z))";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            ZipInput input = (ZipInput) Value.AsNativeValue(arguments[0]).value;
            input.Dispose();
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + " failed, ~s", e.Message);
        }
    }
}
