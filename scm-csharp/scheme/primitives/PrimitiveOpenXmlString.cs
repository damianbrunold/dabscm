using System.IO;
using System.Xml;

namespace scheme;

public class PrimitiveOpenXmlString : Primitive
{
    public override string Name()
    {
        return "open-xml-string";
    }

    public override string Info()
    {
        return
            "Syntax: (open-xml-string source)\n" +
            "Library: (scm xml)\n" +
            "Description: Opens the given XML string and returns an XML reader object for forward-only reading of XML nodes.\n" +
            "Example:\n" +
            "  (define r (open-xml-string \"<a/>\"))\n" +
            "  (xml-node-type r) => element";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        string source = new String(Value.AsString(arguments[0]));
        try
        {
            var reader = XmlReader.Create(new StringReader(source));
            return new NativeValue(reader);
        }
        catch (Exception)
        {
            throw new SchemeError(pos, "open-xml-string: parse error");
        }
    }
}
