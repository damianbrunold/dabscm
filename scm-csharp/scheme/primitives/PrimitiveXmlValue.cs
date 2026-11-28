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
            "Description: Reads the text content of the current element (which must contain no child elements) and returns it as a string, \"\" for an empty element. The reader is left on the element's end-element node.\n" +
            "Example:\n" +
            "  (xml-value reader) => \"John Doe\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            return ((XmlPull) Value.AsNativeValue(arguments[0]).value).ElementText().ToCharArray();
        }
        catch (Exception e)
        {
            throw new SchemeError(pos, "xml-value failed: ~s", e.Message);
        }
    }
}
