package scheme.primitives;

import javax.xml.stream.XMLStreamReader;

import scheme.*;

public class PrimitiveXmlValue extends Primitive {
    @Override
    public String name() {
        return "xml-value";
    }

    @Override
    public String info() {
        return "Syntax: (xml-value xml-reader)\n" +
               "Library: (scm xml)\n" +
               "Description: Reads the text content of the current element (which must contain no child elements) and returns it as a string, \"\" for an empty element. The reader is left on the element's end-element node.\n" +
               "Example:\n" +
               "  (xml-value reader) => \"John Doe\"";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        XMLStreamReader reader = (XMLStreamReader) Value.asNativeValue(arguments[0]).value;
        try {
            var val = reader.getElementText();
            if (val == null) return Value.F;
            return val.toCharArray();
        } catch (Exception e) {
            throw new SchemeError(pos, "xml-value failed: ~s", e.getMessage());
        }
    }
}
