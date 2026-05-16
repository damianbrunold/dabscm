namespace scheme;

public class PrimitiveDeleteFile : Primitive
{
    public override string Name()
    {
        return "delete-file";
    }

    public override string Info()
    {
        return
            "Syntax: (delete-file filename)\n" +
            "Library: (scheme file)\n" +
            "Description: Deletes the named file. Returns unspecified if successful, #f if the file could not be deleted.\n" +
            "Example:\n" +
            "  (delete-file \"temp.txt\")";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var file = new String(Value.AsString(arguments[0]));
        try
        {
            if (!File.Exists(file))
                throw new SchemeError(pos, new FileErrorObject("delete-file: file does not exist: " + file, new object[] { Value.AsString(arguments[0]) }));
            File.Delete(file);
            return new Values();
        }
        catch (SchemeError) { throw; }
        catch (Exception e)
        {
            throw new SchemeError(pos, new FileErrorObject("delete-file: " + e.Message, new object[] { Value.AsString(arguments[0]) }));
        }
    }
}
