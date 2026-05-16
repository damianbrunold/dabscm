using System.Xml;

namespace scheme;

public class PrimitiveCloseXml : Primitive
{
    public override string Name()
    {
        return "close-xml";
    }

    public override string Info()
    {
        return
            "Syntax: (close-xml reader)\n" +
            "Library: (scm core)\n" +
            "Description: Closes the given XML reader, releasing any underlying file or stream resources.\n" +
            "Example:\n" +
            "  (let ((r (open-xml-file \"data.xml\")))\n" +
            "    (close-xml r))";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        try
        {
            XmlReader reader = (XmlReader) Value.AsNativeValue(arguments[0]).value;
            reader.Close();
            reader.Dispose();
            return new Values();
        }
        catch (Exception)
        {
            throw new SchemeError(pos, "close-xml failed");
        }
    }
}
