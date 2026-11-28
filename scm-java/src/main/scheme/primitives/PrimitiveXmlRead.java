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
               "Description: Advances xml-reader to the next node and returns #t, or #f at the end of the document. The XML declaration, a doctype and white space outside the root element are skipped.\n" +
               "Example:\n" +
               "  (xml-read reader) => #t\n" +
               "  (xml-read reader) => #f";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            XMLStreamReader reader = (XMLStreamReader) Value.asNativeValue(arguments[0]).value;
            return XmlInput.next(reader) ? Value.T : Value.F;
        } catch (Exception e) {
            throw new SchemeError(pos, "xml-read failed ~s", e.getMessage());
        }
    }
}
