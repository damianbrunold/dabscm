package scheme.primitives;

import javax.xml.stream.XMLStreamReader;
import javax.xml.stream.events.XMLEvent;

import scheme.*;

public class PrimitiveXmlName extends Primitive {
    @Override
    public String name() {
        return "xml-name";
    }

    @Override
    public String info() {
        return "Syntax: (xml-name xml-reader)\n" +
               "Library: (scm xml)\n" +
               "Description: Returns the qualified name of the current XML element or attribute node as a string.\n" +
               "Example:\n" +
               "  (xml-name reader) => \"Customer\"\n" +
               "  (xml-name reader) => \"ns:Element\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        XMLStreamReader reader = (XMLStreamReader) Value.asNativeValue(arguments[0]).value;
        if (reader.getEventType() == XMLEvent.START_ELEMENT
            || reader.getEventType() == XMLEvent.END_ELEMENT) {
                var prefix = reader.getPrefix();
                if (!prefix.equals("")) {
                    return (prefix + ":" + reader.getLocalName()).toCharArray();
                }
                return reader.getLocalName().toCharArray();
        } else {
            return "";
        }
    }
}
