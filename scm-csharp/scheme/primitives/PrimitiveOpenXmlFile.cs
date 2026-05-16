using System.Xml;

namespace scheme;

public class PrimitiveOpenXmlFile : Primitive
{
    public override string Name()
    {
        return "open-xml-file";
    }

    public override string Info()
    {
        return
            "Syntax: (open-xml-file filename)\n" +
            "Library: (scm core)\n" +
            "Description: Opens the named XML file and returns an XML reader object for forward-only reading of XML nodes.\n" +
            "Example:\n" +
            "  (define r (open-xml-file \"data.xml\"))\n" +
            "  (xml-node-type r) => node-type of first node";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        string filename = new String(Value.AsString(arguments[0]));
        if (!File.Exists(filename))
        {
            throw new SchemeError(pos, "open-xml-file ~a: file not found", filename);
        }
        try
        {
            var reader = XmlReader.Create(filename);
            reader.Read();
            return new NativeValue(reader);
        }
        catch (Exception)
        {
            throw new SchemeError(pos, "open-xml-file ~a: io error", filename);
        }
    }
}
