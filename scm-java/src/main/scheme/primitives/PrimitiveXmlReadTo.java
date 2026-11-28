package scheme.primitives;

import javax.xml.stream.XMLStreamConstants;
import javax.xml.stream.XMLStreamReader;

import scheme.*;

public class PrimitiveXmlReadTo extends Primitive {
    @Override
    public String name() {
        return "xml-read-to";
    }

    @Override
    public String info() {
        return "Syntax: (xml-read-to xml-reader name)\n" +
               "Library: (scm xml)\n" +
               "Description: Advances xml-reader forward until it reaches an element whose qualified or local name is name (a string or symbol). Returns #t if found, or #f if the end of the document is reached first.\n" +
               "Example:\n" +
               "  (xml-read-to reader \"Customer\") => #t\n" +
               "  (xml-read-to reader 'Item) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 2, 2);
        try {
            XMLStreamReader reader = (XMLStreamReader) Value.asNativeValue(arguments[0]).value;
            String name;
            if (Value.isSymbol(arguments[1])) {
                name = Value.asSymbol(arguments[1]);
            } else {
                name = new String(Value.asString(arguments[1]));
            }
            while (XmlInput.next(reader)) {
                if (reader.getEventType() == XMLStreamConstants.START_ELEMENT
                        && (name.equals(reader.getLocalName()) || name.equals(XmlInput.qname(reader)))) {
                    return Value.T;
                }
            }
            return Value.F;
        } catch (Exception e) {
            throw new SchemeError(pos, "xml-read-to failed: %s", e.getMessage());
        }
    }
}
