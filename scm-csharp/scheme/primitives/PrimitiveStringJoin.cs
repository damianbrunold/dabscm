using System.Text;

namespace scheme;

public class PrimitiveStringJoin : Primitive
{
    public override string Name()
    {
        return "string-join";
    }

    public override string Info()
    {
        return
            "Syntax: (string-join strs delim grammar?)\n" +
            "Library: (scm string)\n" +
            "Description: Concatenates a list of strings strs with delim as the separator. The optional grammar argument may be 'infix (default), 'prefix, or 'suffix.\n" +
            "Example:\n" +
            "  (string-join '(\"a\" \"b\" \"c\") \"-\") => \"a-b-c\"\n" +
            "  (string-join '(\"x\" \"y\") \",\" 'suffix) => \"x,y,\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 3);
        object lst = arguments[0];
        char[] sep = new char[] { ' ' };
        string kind = "infix";
        if (arguments.Length > 1)
        {
            sep = Value.AsString(arguments[1]);
        }
        if (arguments.Length > 2)
        {
            kind = Value.AsSymbol(arguments[2]);
        }
        StringBuilder result = new StringBuilder();
        if (kind.Equals("infix"))
        {
            var first = true;
            while (lst != Value.NIL)
            {
                if (!first) result.Append(sep);
                object obj = Value.AsPair(lst).car;
                if (Value.IsString(obj))
                {
                    result.Append(Value.AsString(obj));
                }
                else if (Value.IsSymbol(obj))
                {
                    result.Append(Value.AsSymbol(obj));
                }
                else
                {
                    result.Append(Value.DisplayRep(obj));
                }
                lst = Value.AsPair(lst).cdr;
                first = false;
            }
        }
        else if (kind.Equals("suffix"))
        {
            while (lst != Value.NIL)
            {
                object obj = Value.AsPair(lst).car;
                if (Value.IsString(obj))
                {
                    result.Append(Value.AsString(obj));
                }
                else if (Value.IsSymbol(obj)) {
                    result.Append(Value.AsSymbol(obj));
                }
                else
                {
                    result.Append(Value.DisplayRep(obj));
                }
                result.Append(sep);
                lst = Value.AsPair(lst).cdr;
            }
        }
        else if (kind.Equals("prefix"))
        {
            while (lst != Value.NIL)
            {
                result.Append(sep);
                object obj = Value.AsPair(lst).car;
                if (Value.IsString(obj))
                {
                    result.Append(Value.AsString(obj));
                }
                else if (Value.IsSymbol(obj))
                {
                    result.Append(Value.AsSymbol(obj));
                }
                else
                {
                    result.Append(Value.DisplayRep(obj));
                }
                lst = Value.AsPair(lst).cdr;
            }
        }
        return result.ToString().ToCharArray();
    }
}
