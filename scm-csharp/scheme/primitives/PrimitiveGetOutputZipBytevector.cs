namespace scheme;

public class PrimitiveGetOutputZipBytevector : Primitive
{
    public override string Name() => "get-output-zip-bytevector";

    public override string Info() =>
        "Syntax: (get-output-zip-bytevector zip)\n" +
        "Library: (scm zip)\n" +
        "Description: Returns the contents of an in-memory ZIP archive as a bytevector. " +
        "Must be called after close-output-zip to ensure all entries are flushed.\n" +
        "Example:\n" +
        "  (let ((z (open-output-zip-bytevector)))\n" +
        "    (close-output-zip z)\n" +
        "    (get-output-zip-bytevector z))";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        ZipOutput output = (ZipOutput) Value.AsNativeValue(arguments[0]).value;
        if (output.mem_strm == null)
            throw new SchemeError(pos, "get-output-zip-bytevector: not a bytevector zip port");
        return output.mem_strm.ToArray();
    }
}
