using System.Xml;

namespace scheme;

public class PrimitiveXmlAttribute : Primitive
{
    public override string Name()
    {
        return "xml-attribute";
    }

    public override string Info()
    {
        return
            "Syntax: (xml-attribute xml-reader name)\n" +
            "Library: (scm xml)\n" +
            "Description: Returns the value of the named attribute from the current element of xml-reader as a string, or #f if the attribute does not exist.\n" +
            "Example:\n" +
            "  (xml-attribute reader \"id\") => \"42\"\n" +
            "  (xml-attribute reader 'class) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        XmlReader reader = (XmlReader) Value.AsNativeValue(arguments[0]).value;
        if (Value.IsSymbol(arguments[1]))
        {
            var val = reader.GetAttribute(Value.AsSymbol(arguments[1]));
            if (val == null) return Value.F;
            return val.ToCharArray();
        }
        else
        {
            var val = reader.GetAttribute(new String(Value.AsString(arguments[1])));
            if (val == null) return Value.F;
            return val.ToCharArray();
        }
    }
}
