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
            "Description: Returns the qualified name (prefix:local) of the current element or end-element node as a string, \"\" for other nodes.\n" +
            "Example:\n" +
            "  (xml-name reader) => \"Customer\"\n" +
            "  (xml-name reader) => \"ns:Element\"";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 1, 1);
        var x = (XmlPull) Value.AsNativeValue(arguments[0]).value;
        if (x.Current == XmlPull.Kind.Element || x.Current == XmlPull.Kind.EndElement)
            return x.CurrentName.ToCharArray();
        return "".ToCharArray();
    }
}
