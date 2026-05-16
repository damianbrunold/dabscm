namespace scheme;

public class PrimitiveZipEntryNames : Primitive
{
    public override string Name()
    {
        return "zip-entry-names";
    }

    public override string Info()
    {
        return
            "Syntax: (zip-entry-names zip)\n" +
            "Library: (scm zip)\n" +
            "Description: Returns a list of entry name strings in the ZIP archive zip.\n" +
            "Example:\n" +
            "  (zip-entry-names z) => (\"file1.txt\" \"dir/file2.txt\")";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            ZipInput input = (ZipInput) Value.AsNativeValue(arguments[0]).value;
            object result = Value.NIL;
            var names = input.zip.Entries.Select(e => e.FullName).ToList();
            for (int i = names.Count - 1; i >= 0; i--)
                result = new Pair(names[i].ToCharArray(), result);
            return result;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, Name() + " failed, ~s", e.Message);
        }
    }
}
