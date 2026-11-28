using System.Xml;

namespace scheme;

public class PrimitiveXmlReadTo : Primitive
{
    public override string Name()
    {
        return "xml-read-to";
    }

    public override string Info()
    {
        return
            "Syntax: (xml-read-to xml-reader name)\n" +
            "Library: (scm xml)\n" +
            "Description: Advances xml-reader forward until it reaches an element whose qualified or local name is name (a string or symbol). Returns #t if found, or #f if the end of the document is reached first.\n" +
            "Example:\n" +
            "  (xml-read-to reader \"Customer\") => #t\n" +
            "  (xml-read-to reader 'Item) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        try
        {
            var x = (XmlPull) Value.AsNativeValue(arguments[0]).value;
            string name = Value.IsSymbol(arguments[1]) ? Value.AsSymbol(arguments[1]) : new String(Value.AsString(arguments[1]));
            string colonName = ":" + name;
            while (x.Read())
            {
                if (x.Current == XmlPull.Kind.Element
                    && (x.CurrentName == name || x.CurrentName.EndsWith(colonName)))
                    return Value.T;
            }
            return Value.F;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "xml-read-to failed: ~s", e.Message);
        }
    }
}
