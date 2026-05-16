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
            "Description: Advances xml-reader forward until it reaches an element with the given name. Returns #t if found, or #f if the end of the document is reached first.\n" +
            "Example:\n" +
            "  (xml-read-to reader \"Customer\") => #t\n" +
            "  (xml-read-to reader 'Item) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        try
        {
            XmlReader reader = (XmlReader) Value.AsNativeValue(arguments[0]).value;
            if (Value.IsSymbol(arguments[1]))
            {
                if (reader.ReadToFollowing(Value.AsSymbol(arguments[1])))
                {
                    return Value.T;
                }
            }
            else
            {
                if (reader.ReadToFollowing(new String(Value.AsString(arguments[1]))))
                {
                    return Value.T;
                }
            }
            return Value.F;
        }
        catch (Exception)
        {
            throw new SchemeError(pos, "xml-read-to failed");
        }
    }
}
