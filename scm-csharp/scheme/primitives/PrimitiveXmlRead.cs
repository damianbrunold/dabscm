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
            "Description: Advances xml-reader to the next node and returns #t, or #f at the end of the document. The XML declaration, a doctype and white space outside the root element are skipped.\n" +
            "Example:\n" +
            "  (xml-read reader) => #t\n" +
            "  (xml-read reader) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            return ((XmlPull) Value.AsNativeValue(arguments[0]).value).Read() ? Value.T : Value.F;
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "xml-read failed ~s", e.Message);
        }
    }
}
