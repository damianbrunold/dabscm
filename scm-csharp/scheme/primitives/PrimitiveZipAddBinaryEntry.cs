namespace scheme;

public class PrimitiveZipAddBinaryEntry: Primitive
{
    public override string Name()
    {
        return "zip-add-binary-entry";
    }

    public override string Info()
    {
        return
            "Syntax: (zip-add-binary-entry zip name [timestamp])\n" +
            "Library: (scm zip)\n" +
            "Description: Creates a new binary entry named name in the ZIP archive zip and\n" +
            "  returns an output binary port for writing to it. The optional timestamp is a\n" +
            "  Unix epoch in seconds.\n" +
            "Example:\n" +
            "  (let ((port (zip-add-binary-entry zip \"data.bin\"))) (write-bytevector bv port))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        try
        {
            ZipOutput output = (ZipOutput) Value.AsNativeValue(arguments[0]).value;
            string entryname = new(Value.AsString(arguments[1]));
            output.text_strm?.Dispose();
            output.bin_strm?.Dispose();
            var entry = output.zip!.CreateEntry(entryname);
            if (arguments.Length > 2)
            {
                var dt = DateTimeOffset.FromUnixTimeSeconds(IntegerMath.ToLong(arguments[2]));
                var zipEpoch = new DateTimeOffset(1980, 1, 1, 0, 0, 0, TimeSpan.Zero);
                entry.LastWriteTime = dt < zipEpoch ? zipEpoch : dt;
            }
            output.bin_strm = entry.Open();
            return new BinaryOutputStream(output.bin_strm);
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + " failed, ~s", e.Message);
        }
    }
}
