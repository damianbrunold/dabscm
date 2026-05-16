namespace scheme;

public class PrimitiveZipAddTextEntry : Primitive
{
    public override string Name()
    {
        return "zip-add-text-entry";
    }

    public override string Info()
    {
        return
            "Syntax: (zip-add-text-entry zip name [timestamp])\n" +
            "Library: (scm zip)\n" +
            "Description: Creates a new text entry named name in the ZIP archive zip and\n" +
            "  returns a UTF-8 textual output port for writing to it. The optional timestamp\n" +
            "  is a Unix epoch in seconds.\n" +
            "Example:\n" +
            "  (let ((port (zip-add-text-entry zip \"readme.txt\"))) (display \"Hello\" port))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        try
        {
            ZipOutput output = (ZipOutput) Value.AsNativeValue(arguments[0]).value;
            string entryname = new(Value.AsString(arguments[1]));
            output.bin_strm?.Dispose();
            output.text_strm?.Dispose();
            var entry = output.zip!.CreateEntry(entryname);
            if (arguments.Length > 2)
            {
                var dt = DateTimeOffset.FromUnixTimeSeconds(IntegerMath.ToLong(arguments[2]));
                var zipEpoch = new DateTimeOffset(new DateTime(1980, 1, 1, 0, 0, 0, DateTimeKind.Local));
                entry.LastWriteTime = dt < zipEpoch ? zipEpoch : dt;
            }
            output.text_strm = new StreamWriter(entry.Open(), Encodings.GetEncoding("utf8"));
            return output.text_strm;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + " failed, ~s", e.Message);
        }
    }
}
