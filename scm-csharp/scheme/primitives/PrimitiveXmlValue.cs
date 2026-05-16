using System.Xml;

namespace scheme;

public class PrimitiveXmlValue : Primitive
{
    public override string Name()
    {
        return "xml-value";
    }

    public override string Info()
    {
        return
            "Syntax: (xml-value xml-reader)\n" +
            "Library: (scm xml)\n" +
            "Description: Reads and returns the text content of the current element as a string, or #f if there is no value.\n" +
            "Example:\n" +
            "  (xml-value reader) => \"John Doe\"\n" +
            "  (xml-value reader) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        XmlReader reader = (XmlReader) Value.AsNativeValue(arguments[0]).value;
        var val = reader.ReadElementContentAsString();
        if (val == null) return Value.F;
        return val.ToCharArray();
    }
}
