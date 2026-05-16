package scheme.primitives;

import java.io.ByteArrayInputStream;

import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamReader;

import scheme.*;

public class PrimitiveOpenXmlBytevector extends Primitive {
    @Override
    public String name() {
        return "open-xml-bytevector";
    }

    @Override
    public String info() {
        return "Syntax: (open-xml-bytevector bv)\n" +
               "Library: (scm xml)\n" +
               "Description: Opens the XML document encoded in the given bytevector and returns an XML reader for forward-only reading of XML nodes. The byte stream is decoded using the XML declaration's encoding, defaulting to UTF-8.\n" +
               "Example:\n" +
               "  (define r (open-xml-bytevector (string->utf8 \"<a/>\")))\n" +
               "  (xml-node-type r) => element";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        byte[] bytes = Value.asBytevector(arguments[0]);
        try {
            XMLInputFactory xmlif = XMLInputFactory.newInstance();
            XMLStreamReader xmlr = xmlif.createXMLStreamReader(new ByteArrayInputStream(bytes));
            return new NativeValue(xmlr);
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": parse error");
        }
    }
}
