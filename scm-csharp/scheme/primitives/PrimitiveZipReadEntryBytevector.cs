namespace scheme;

public class PrimitiveZipReadEntryBytevector : Primitive
{
    public override string Name()
    {
        return "zip-read-entry-bytevector";
    }

    public override string Info()
    {
        return
            "Syntax: (zip-read-entry-bytevector zip name)\n" +
            "Library: (scm zip)\n" +
            "Description: Reads the contents of the entry named name from the ZIP archive zip and returns it as a bytevector.\n" +
            "Example:\n" +
            "  (zip-read-entry-bytevector z \"hello.txt\") => #u8(72 101 108 108 111)";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        try
        {
            ZipInput input = (ZipInput) Value.AsNativeValue(arguments[0]).value;
            string name = new(Value.AsString(arguments[1]));
            var entry = input.zip.GetEntry(name);
            if (entry == null)
                throw new SchemeError(pos, Name() + ": entry not found, ~s", name);
            using var stream = entry.Open();
            using var ms = new MemoryStream();
            stream.CopyTo(ms);
            return ms.ToArray();
        }
        catch (SchemeError)
        {
            throw;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + " failed, ~s", e.Message);
        }
    }
}
