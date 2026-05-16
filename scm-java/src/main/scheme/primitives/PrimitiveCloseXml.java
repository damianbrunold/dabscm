package scheme.primitives;

import javax.xml.stream.XMLStreamReader;

import scheme.*;

public class PrimitiveCloseXml extends Primitive {
    @Override
    public String name() {
        return "close-xml";
    }

    @Override
    public String info() {
        return "Syntax: (close-xml reader)\n" +
               "Library: (scm core)\n" +
               "Description: Closes the given XML reader, releasing any underlying file or stream resources.\n" +
               "Example:\n" +
               "  (let ((r (open-xml-file \"data.xml\")))\n" +
               "    (close-xml r))";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        try {
            XMLStreamReader reader = (XMLStreamReader) Value.asNativeValue(arguments[0]).value;
            reader.close();
            return new Values();
        } catch (Exception e) {
            throw new SchemeError(pos, "close-xml failed: ~s", e.getMessage());
        }
    }
}
