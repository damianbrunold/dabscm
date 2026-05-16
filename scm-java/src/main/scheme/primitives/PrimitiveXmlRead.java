package scheme.primitives;

import javax.xml.stream.XMLStreamReader;

import scheme.*;

public class PrimitiveXmlRead extends Primitive {
    @Override
    public String name() {
        return "xml-read";
    }

    @Override
    public String info() {
        return "Syntax: (xml-read xml-reader)\n" +
               "Library: (scm xml)\n" +
               "Description: Advances xml-reader to the next node in the XML document. Returns #t if a node was read, or #f if the end of the document was reached.\n" +
               "Example:\n" +
               "  (xml-read reader) => #t\n" +
               "  (xml-read reader) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            XMLStreamReader reader = (XMLStreamReader) Value.asNativeValue(arguments[0]).value;
            if (!reader.hasNext()) return Value.F;
            reader.next();
            return Value.T;
        } catch (Exception e) {
            throw new SchemeError(pos, "xml-read failed ~s", e.getMessage());
        }
    }
}
