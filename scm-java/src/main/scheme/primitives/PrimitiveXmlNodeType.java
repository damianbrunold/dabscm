package scheme.primitives;

import javax.xml.stream.XMLStreamReader;
import javax.xml.stream.events.XMLEvent;

import scheme.*;

public class PrimitiveXmlNodeType extends Primitive {
    @Override
    public String name() {
        return "xml-node-type";
    }

    @Override
    public String info() {
        return "Syntax: (xml-node-type xml-reader)\n" +
               "Library: (scm xml)\n" +
               "Description: Returns a symbol identifying the type of the current XML node: element, end-element, text, cdata, comment, pi, xml-decl, doc, doc-type, entity-ref, or #f for unrecognized types.\n" +
               "Example:\n" +
               "  (xml-node-type reader) => element\n" +
               "  (xml-node-type reader) => text";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        XMLStreamReader reader = (XMLStreamReader) Value.asNativeValue(arguments[0]).value;
        switch (reader.getEventType()) {
            case XMLEvent.START_ELEMENT:
                return Value.intern("element");
            case XMLEvent.CHARACTERS:
                return Value.intern("text");
            case XMLEvent.CDATA:
                return Value.intern("cdata");
            case XMLEvent.PROCESSING_INSTRUCTION:
                return Value.intern("pi");
            case XMLEvent.COMMENT:
                return Value.intern("comment");
            case XMLEvent.START_DOCUMENT:
                return Value.intern("doc");
            case XMLEvent.ENTITY_REFERENCE:
                return Value.intern("entity-ref");
            case XMLEvent.END_ELEMENT:
                return Value.intern("end-element");
            default:
                return Value.F;
        }
    }
}
