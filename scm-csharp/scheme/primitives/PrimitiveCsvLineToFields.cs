using System.Text.RegularExpressions;

namespace scheme;

public class PrimitiveCsvLineToFields : Primitive
{
    public override string Name()
    {
        return "csv-line->fields";
    }

    public override string Info()
    {
        return
            "Syntax: (csv-line->fields str sep) (csv-line->fields str sep 'trim)\n" +
            "Library: (scm core)\n" +
            "Description: Splits a CSV line string using the given separator, stripping surrounding double-quotes from each field. When 'trim is given as a third argument, also trims whitespace from each field.\n" +
            "Example:\n" +
            "  (csv-line->fields \"a,b,c\" \",\") => (\"a\" \"b\" \"c\")\n" +
            "  (csv-line->fields \"\\\"hello\\\",world\" \",\") => (\"hello\" \"world\")";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 3);
        string s = new String(Value.AsString(arguments[0]));
        string sep = new String(Value.AsString(arguments[1]));
        bool trim = false;
        if (arguments.Length > 2 && arguments[2].Equals("trim"))
        {
            trim = true;
        }
        string[] parts = s.Split(sep);
        var result = new object[parts.Length];

        for (int i = 0; i < parts.Length; i++)
        {
            var part = parts[i];
            if (part.StartsWith("\"") && part.EndsWith("\""))
            {
                part = part.Substring(1, part.Length - 2);
            }
            if (trim)
            {
                part = part.Trim();
            }
            result[i] = part.ToCharArray();
        }
        return result;
    }
}
