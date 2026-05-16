using System.Text;

namespace scheme;

public class PrimitiveGetBytes : Primitive
{
    public override string Name()
    {
        return "get-bytes";
    }

    public override string Info()
    {
        return
            "Syntax: (get-bytes obj [encoding])\n" +
            "Library: (scm core)\n" +
            "Description: Returns the byte representation of obj (string, symbol, or bytevector) as a bytevector.\n" +
            "  encoding is an optional string or symbol specifying the character encoding (default: utf-8).\n" +
            "  Supported encodings: utf-8, utf-8-bom, latin-1, utf-16, utf-16-le.\n" +
            "Example:\n" +
            "  (get-bytes \"hello\")\n" +
            "  (get-bytes \"hello\" \"latin-1\")";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 2);
        Encoding encoding = Encoding.UTF8;
        if (arguments.Length == 2)
        {
            string encName = Value.IsSymbol(arguments[1])
                ? Value.AsSymbol(arguments[1])
                : new String(Value.AsString(arguments[1]));
            encoding = Encodings.GetEncoding(encName);
        }
        if (Value.IsString(arguments[0]))
        {
            return encoding.GetBytes(Value.AsString(arguments[0]));
        }
        else if (Value.IsSymbol(arguments[0]))
        {
            return encoding.GetBytes(Value.AsSymbol(arguments[0]));
        }
        else if (Value.IsBytevector(arguments[0]))
        {
            return arguments[0];
        }
        else if (arguments[0] != null)
        {
            var s = arguments[0].ToString();
            return encoding.GetBytes(s!);
        }
        else
        {
            throw new SchemeError(pos, Name() + ": Cannot get bytes from value");
        }
    }
}
