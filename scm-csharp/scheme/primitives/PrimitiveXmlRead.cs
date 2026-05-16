using System.Xml;

namespace scheme;

public class PrimitiveXmlRead : Primitive
{
    public override string Name()
    {
        return "xml-read";
    }

    public override string Info()
    {
        return
            "Syntax: (xml-read xml-reader)\n" +
            "Library: (scm xml)\n" +
            "Description: Advances xml-reader to the next node in the XML document. Returns #t if a node was read, or #f if the end of the document was reached.\n" +
            "Example:\n" +
            "  (xml-read reader) => #t\n" +
            "  (xml-read reader) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            XmlReader reader = (XmlReader) Value.AsNativeValue(arguments[0]).value;
            if (reader.Read()) return Value.T;
            return Value.F;
        }
        catch (Exception)
        {
            throw new SchemeError(pos, "xml-read failed");
        }
    }
}
