namespace scheme;

public class PrimitiveZipEntrySize : Primitive
{
    public override string Name() => "zip-entry-size";

    public override string Info() =>
        "Syntax: (zip-entry-size zip name)\n" +
        "Library: (scm zip)\n" +
        "Description: Returns the uncompressed size in bytes the archive declares for the entry named\n" +
        "  name, or #f if it declares none. Check it before reading an entry of an archive you did not\n" +
        "  make (a small archive can unpack to gigabytes); zip-extract-entry also enforces a limit.\n" +
        "Example:\n" +
        "  (zip-entry-size z \"hello.txt\") => 5";

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        ZipInput input = (ZipInput) Value.AsNativeValue(arguments[0]).value;
        string name = new(Value.AsString(arguments[1]));
        var entry = input.zip.GetEntry(name);
        if (entry == null)
            throw new SchemeError(pos, Name() + ": entry not found, ~s", name);
        return entry.Length;
    }
}
