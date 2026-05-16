using System.IO;
using System.Xml;

namespace scheme;

public class PrimitiveOpenXmlBytevector : Primitive
{
    public override string Name()
    {
        return "open-xml-bytevector";
    }

    public override string Info()
    {
        return
            "Syntax: (open-xml-bytevector bv)\n" +
            "Library: (scm xml)\n" +
            "Description: Opens the XML document encoded in the given bytevector and returns an XML reader for forward-only reading of XML nodes. The byte stream is decoded using the XML declaration's encoding, defaulting to UTF-8.\n" +
            "Example:\n" +
            "  (define r (open-xml-bytevector (string->utf8 \"<a/>\")))\n" +
            "  (xml-node-type r) => element";
    }

    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        byte[] bytes = Value.AsBytevector(arguments[0]);
        try
        {
            var reader = XmlReader.Create(new MemoryStream(bytes));
            return new NativeValue(reader);
        }
        catch (Exception)
        {
            throw new SchemeError(pos, "open-xml-bytevector: parse error");
        }
    }
}
