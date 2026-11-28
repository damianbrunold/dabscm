using System.Xml;

namespace scheme;

public class PrimitiveXmlAttribute : Primitive
{
    public override string Name()
    {
        return "xml-attribute";
    }

    public override string Info()
    {
        return
            "Syntax: (xml-attribute xml-reader name)\n" +
            "Library: (scm xml)\n" +
            "Description: Returns the value of the attribute with the given qualified or local name of the current element as a string, or #f if the attribute does not exist or the current node is not an element.\n" +
            "Example:\n" +
            "  (xml-attribute reader \"id\") => \"42\"\n" +
            "  (xml-attribute reader 'class) => #f";
    }
    
    public override object Apply(SourcePos? pos, object[] arguments)
    {
        CheckArgs(pos, arguments, 2, 2);
        var x = (XmlPull) Value.AsNativeValue(arguments[0]).value;
        string name = Value.IsSymbol(arguments[1]) ? Value.AsSymbol(arguments[1]) : new String(Value.AsString(arguments[1]));
        var val = x.Attribute(name);
        if (val == null) return Value.F;
        return val.ToCharArray();
    }
}
