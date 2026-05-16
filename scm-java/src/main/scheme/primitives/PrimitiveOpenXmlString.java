package scheme.primitives;

import java.io.StringReader;

import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamReader;

import scheme.*;

public class PrimitiveOpenXmlString extends Primitive {
    @Override
    public String name() {
        return "open-xml-string";
    }

    @Override
    public String info() {
        return "Syntax: (open-xml-string source)\n" +
               "Library: (scm xml)\n" +
               "Description: Opens the given XML string and returns an XML reader object for forward-only reading of XML nodes.\n" +
               "Example:\n" +
               "  (define r (open-xml-string \"<a/>\"))\n" +
               "  (xml-node-type r) => element";
    }

    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        String source = new String(Value.asString(arguments[0]));
        try {
            XMLInputFactory xmlif = XMLInputFactory.newInstance();
            XMLStreamReader xmlr = xmlif.createXMLStreamReader(new StringReader(source));
            return new NativeValue(xmlr);
        } catch (Exception e) {
            throw new SchemeError(pos, name() + ": parse error");
        }
    }
}
