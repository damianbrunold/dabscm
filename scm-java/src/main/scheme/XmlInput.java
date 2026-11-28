package scheme;

import javax.xml.stream.XMLInputFactory;

// The StAX factory behind open-xml-file/-string/-bytevector. XML read by
// scm programs often comes from outside (uploads, pasted text, feeds), so
// DTDs and external entities are off: a DOCTYPE cannot fetch URLs or read
// local files (XXE) nor expand entity bombs. Matches .NET's XmlReader
// default (DtdProcessing.Prohibit).
public final class XmlInput {
    private XmlInput() {}

    /** Advances to the next event of (scm xml): the document start and end,
     *  a doctype and ignorable whitespace give none. False at the end. */
    public static boolean next(javax.xml.stream.XMLStreamReader r)
            throws javax.xml.stream.XMLStreamException {
        while (r.hasNext()) {
            int ev = r.next();
            switch (ev) {
                case javax.xml.stream.XMLStreamConstants.END_DOCUMENT:
                    return false;
                case javax.xml.stream.XMLStreamConstants.DTD:
                case javax.xml.stream.XMLStreamConstants.SPACE:
                case javax.xml.stream.XMLStreamConstants.START_DOCUMENT:
                    continue;
                default:
                    return true;
            }
        }
        return false;
    }

    /** The qualified name of the current element or end element */
    public static String qname(javax.xml.stream.XMLStreamReader r) {
        String prefix = r.getPrefix();
        if (prefix != null && !prefix.isEmpty()) return prefix + ":" + r.getLocalName();
        return r.getLocalName();
    }

    public static XMLInputFactory factory() {
        XMLInputFactory f = XMLInputFactory.newInstance();
        f.setProperty(XMLInputFactory.SUPPORT_DTD, Boolean.FALSE);
        f.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, Boolean.FALSE);
        // one text event per run of character data (entity references and
        // CDATA sections merged), as in the .NET and native readers
        f.setProperty(XMLInputFactory.IS_COALESCING, Boolean.TRUE);
        f.setXMLResolver((publicID, systemID, baseURI, namespace) -> {
            throw new javax.xml.stream.XMLStreamException("external entities are disabled");
        });
        return f;
    }
}
