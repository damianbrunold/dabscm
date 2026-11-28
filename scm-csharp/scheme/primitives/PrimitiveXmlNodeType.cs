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
            "Description: Returns a symbol for the current node: element, end-element (also after an empty element such as <br/>), text (one node per run of character data, with character references and CDATA sections merged), comment or pi; #f before the first xml-read and at the end.\n" +
            "Example:\n" +
            "  (xml-node-type reader) => element\n" +
            "  (xml-node-type reader) => text";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        switch (((XmlPull) Value.AsNativeValue(arguments[0]).value).Current)
        {
            case XmlPull.Kind.Element: return Value.Intern("element");
            case XmlPull.Kind.EndElement: return Value.Intern("end-element");
            case XmlPull.Kind.Text: return Value.Intern("text");
            case XmlPull.Kind.Comment: return Value.Intern("comment");
            case XmlPull.Kind.Pi: return Value.Intern("pi");
            default: return Value.F;
        }
    }
}
