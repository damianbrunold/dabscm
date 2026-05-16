package scheme.primitives;

import java.io.*;

import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamReader;

import scheme.*;

public class PrimitiveOpenXmlFile extends Primitive {
    @Override
    public String name() {
        return "open-xml-file";
    }

    @Override
    public String info() {
        return "Syntax: (open-xml-file filename)\n" +
               "Library: (scm core)\n" +
               "Description: Opens the named XML file and returns an XML reader object for forward-only reading of XML nodes.\n" +
               "Example:\n" +
               "  (define r (open-xml-file \"data.xml\"))\n" +
               "  (xml-node-type r) => node-type of first node";
    }
    
    @Override
    public Object apply(SourcePos pos, Object[] arguments) {
        checkArgs(pos, arguments, 1, 1);
        String filename = new String(Value.asString(arguments[0]));
        if (!new File(filename).exists()) {
            throw new SchemeError(pos, name() + " ~a: file not found", filename);
        }
        try {
            XMLInputFactory xmlif = XMLInputFactory.newInstance();
            XMLStreamReader xmlr = xmlif.createXMLStreamReader(filename,
                                   new FileInputStream(filename));
            return new NativeValue(xmlr);
        } catch (Exception e) {
            throw new SchemeError(pos, name() + " ~a: io error", filename);
        }
    }
}
