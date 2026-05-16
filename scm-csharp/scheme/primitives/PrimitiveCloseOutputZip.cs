namespace scheme;

public class PrimitiveCloseOutputZip : Primitive
{
    public override string Name()
    {
        return "close-output-zip";
    }

    public override string Info()
    {
        return
            "Syntax: (close-output-zip zip)\n" +
            "Library: (scm core)\n" +
            "Description: Closes the given zip output archive, flushing and releasing all underlying resources.\n" +
            "Example:\n" +
            "  (let ((z (open-output-zip-file \"archive.zip\")))\n" +
            "    (close-output-zip z))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            ZipOutput output = (ZipOutput) Value.AsNativeValue(arguments[0]).value;
            output.text_strm?.Close();
            output.bin_strm?.Close();
            output.Dispose();
            return new Values();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + " close-output-zip failed, ~s", e.Message);
        }
    }
}
