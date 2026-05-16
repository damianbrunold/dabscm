using System.Text;

namespace scheme;

public class PrimitiveOpenJsonFile : Primitive
{
    public override string Name()
    {
        return "open-json-file";
    }

    public override string Info()
    {
        return
            "Syntax: (open-json-file filename)\n" +
            "Library: (scm core)\n" +
            "Description: Opens the named JSON file and returns a JSON reader object. An optional list-id symbol may be specified to identify list nodes.\n" +
            "Example:\n" +
            "  (define r (open-json-file \"data.json\"))\n" +
            "  (json-next-object r) => next parsed JSON object";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        string filename = new String(Value.AsString(arguments[0]));
        if (!File.Exists(filename))
        {
            throw new SchemeError(pos, "open-json-file ~a: file not found", filename);
        }
        try
        {
            Encoding encoding = Encoding.UTF8;
            var reader = new StreamReader(
                new FileStream(filename, FileMode.Open, FileAccess.Read, FileShare.ReadWrite),
                encoding
            );
            var parser = new JsonParser(reader);
            if (arguments.Length == 2)
            {
                if (Value.IsSymbol(arguments[1]))
                {
                    parser.WithListId(Value.AsSymbol(arguments[1]));
                }
                else
                {
                    parser.WithListId(new String(Value.AsString(arguments[1])));
                }
            }
            return new NativeValue(parser);
        }
        catch (Exception)
        {
            throw new SchemeError(pos, "open-json-file ~a: io error", filename);
        }
    }
}
