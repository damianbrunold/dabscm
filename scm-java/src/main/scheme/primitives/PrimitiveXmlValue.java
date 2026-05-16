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
               "Description: Reads and returns the text content of the current element as a string, or #f if there is no value.\n" +
               "Example:\n" +
               "  (xml-value reader) => \"John Doe\"\n" +
               "  (xml-value reader) => #f";
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
