package scheme.primitives;

import javax.xml.stream.XMLStreamReader;

import scheme.*;

public class PrimitiveXmlAttribute extends Primitive {
    @Override
    public String name() {
        return "xml-attribute";
    }

    @Override
    public String info() {
        return "Syntax: (xml-attribute xml-reader name)\n" +
               "Library: (scm xml)\n" +
               "Description: Returns the value of the named attribute from the current element of xml-reader as a string, or #f if the attribute does not exist.\n" +
               "Example:\n" +
               "  (xml-attribute reader \"id\") => \"42\"\n" +
               "  (xml-attribute reader 'class) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        XMLStreamReader reader = (XMLStreamReader) Value.asNativeValue(arguments[0]).value;
        String name;
        if (Value.isSymbol(arguments[1])) {
            name = Value.asSymbol(arguments[1]);
        } else {
            name = new String(Value.asString(arguments[1]));
        }
        for (var i = 0; i < reader.getAttributeCount(); i++) {
            if (reader.getAttributeLocalName(i).equals(name)) {
                return reader.getAttributeValue(i).toCharArray();
            }
        }
        return Value.F;
    }
}
