using System.Xml;

namespace scheme;

public class PrimitiveXmlNodeType : Primitive
{
    public override string Name()
    {
        return "xml-node-type";
    }

    public override string Info()
    {
        return
            "Syntax: (xml-node-type xml-reader)\n" +
            "Library: (scm xml)\n" +
            "Description: Returns a symbol identifying the type of the current XML node: element, end-element, text, cdata, comment, pi, xml-decl, doc, doc-type, entity-ref, or #f for unrecognized types.\n" +
            "Example:\n" +
            "  (xml-node-type reader) => element\n" +
            "  (xml-node-type reader) => text";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        XmlReader reader = (XmlReader) Value.AsNativeValue(arguments[0]).value;
        switch (reader.NodeType)
        {
            case XmlNodeType.Element:
                return Value.Intern("element");
            case XmlNodeType.Text:
            case XmlNodeType.Whitespace:
                return Value.Intern("text");
            case XmlNodeType.CDATA:
                return Value.Intern("cdata");
            case XmlNodeType.ProcessingInstruction:
                return Value.Intern("pi");
            case XmlNodeType.Comment:
                return Value.Intern("comment");
            case XmlNodeType.XmlDeclaration:
                return Value.Intern("xml-decl");
            case XmlNodeType.Document:
                return Value.Intern("doc");
            case XmlNodeType.DocumentType:
                return Value.Intern("doc-type");
            case XmlNodeType.EntityReference:
                return Value.Intern("entity-ref");
            case XmlNodeType.EndElement:
                return Value.Intern("end-element");
            default:
                return Value.F;
        }
    }
}
