using System.Xml;

namespace scheme;

// The reader settings behind open-xml-file/-string/-bytevector. XML read by
// scm programs often comes from outside (uploads, pasted text, feeds): no
// DTDs (no entity bombs) and no resolver (no external entities, XXE) —
// stated explicitly rather than relying on the framework defaults. The
// Java runtime does the same in XmlInput.java.
public static class XmlInput
{
    public static XmlReaderSettings Settings()
    {
        return new XmlReaderSettings
        {
            DtdProcessing = DtdProcessing.Prohibit,
            XmlResolver = null,
        };
    }
}
