package scheme;

import javax.xml.stream.XMLInputFactory;

// The StAX factory behind open-xml-file/-string/-bytevector. XML read by
// scm programs often comes from outside (uploads, pasted text, feeds), so
// DTDs and external entities are off: a DOCTYPE cannot fetch URLs or read
// local files (XXE) nor expand entity bombs. Matches .NET's XmlReader
// default (DtdProcessing.Prohibit).
public final class XmlInput {
    private XmlInput() {}

    public static XMLInputFactory factory() {
        XMLInputFactory f = XMLInputFactory.newInstance();
        f.setProperty(XMLInputFactory.SUPPORT_DTD, Boolean.FALSE);
        f.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, Boolean.FALSE);
        f.setXMLResolver((publicID, systemID, baseURI, namespace) -> {
            throw new javax.xml.stream.XMLStreamException("external entities are disabled");
        });
        return f;
    }
}
