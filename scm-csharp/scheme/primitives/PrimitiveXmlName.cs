using System.Xml;

namespace scheme;

public class PrimitiveXmlName : Primitive
{
    public override string Name()
    {
        return "xml-name";
    }

    public override string Info()
    {
        return
            "Syntax: (xml-name xml-reader)\n" +
            "Library: (scm xml)\n" +
            "Description: Returns the qualified name of the current XML element or attribute node as a string.\n" +
            "Example:\n" +
            "  (xml-name reader) => \"Customer\"\n" +
            "  (xml-name reader) => \"ns:Element\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        XmlReader reader = (XmlReader) Value.AsNativeValue(arguments[0]).value;
        return reader.Name.ToCharArray();
    }
}
