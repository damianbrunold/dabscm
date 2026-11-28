using System.Xml;

namespace scheme;

// The reader settings behind open-xml-file/-string/-bytevector. XML read by
// scm programs often comes from outside (uploads, pasted text, feeds): no
// DTD processing (no entity bombs; a doctype is skipped) and no resolver (no external entities, XXE) —
// stated explicitly rather than relying on the framework defaults. The
// Java runtime does the same in XmlInput.java.
public static class XmlInput
{
    public static XmlReaderSettings Settings()
    {
        return new XmlReaderSettings
        {
            DtdProcessing = DtdProcessing.Ignore,
            XmlResolver = null,
        };
    }
}

// The event stream of (scm xml), the same in the three implementations:
// elements and end elements (an empty element gives both), one text event
// per run of character data (entity references, CDATA sections and
// whitespace merged), comments and processing instructions. The XML
// declaration, a doctype and whitespace outside the root element give no
// events; after the root element ends (and trailing comments), Read
// returns false.
public sealed class XmlPull
{
    public enum Kind { None, Element, EndElement, Text, Comment, Pi }

    private readonly XmlReader reader;
    private bool lookahead;      // reader is on a node not yet reported
    private bool lookaheadEof;   // ... or at the end
    private bool pendingEnd;     // the current element was empty: an end follows
    public Kind Current { get; private set; } = Kind.None;
    public string CurrentName { get; private set; } = "";

    public XmlPull(XmlReader reader) { this.reader = reader; }

    public XmlReader Reader => reader;

    private static bool IsText(XmlNodeType t) =>
        t == XmlNodeType.Text || t == XmlNodeType.CDATA
        || t == XmlNodeType.Whitespace || t == XmlNodeType.SignificantWhitespace;

    private bool Advance()
    {
        if (lookahead) { lookahead = false; return !lookaheadEof; }
        return reader.Read();
    }

    public bool Read()
    {
        if (pendingEnd)
        {
            pendingEnd = false;
            Current = Kind.EndElement;
            return true;
        }
        while (true)
        {
            if (!Advance()) { Current = Kind.None; CurrentName = ""; return false; }
            var t = reader.NodeType;
            if (IsText(t))
            {
                if (reader.Depth == 0) continue; // whitespace outside the root
                while (true)
                {
                    if (!reader.Read()) { lookahead = true; lookaheadEof = true; break; }
                    if (!IsText(reader.NodeType)) { lookahead = true; lookaheadEof = false; break; }
                }
                Current = Kind.Text; CurrentName = "";
                return true;
            }
            switch (t)
            {
                case XmlNodeType.Element:
                    Current = Kind.Element; CurrentName = reader.Name;
                    pendingEnd = reader.IsEmptyElement;
                    return true;
                case XmlNodeType.EndElement:
                    Current = Kind.EndElement; CurrentName = reader.Name;
                    return true;
                case XmlNodeType.Comment:
                    Current = Kind.Comment; CurrentName = "";
                    return true;
                case XmlNodeType.ProcessingInstruction:
                    Current = Kind.Pi; CurrentName = "";
                    return true;
                default:
                    continue; // declaration, doctype, ...
            }
        }
    }

    // The text of the current element up to its end, leaving the reader on
    // the end element (as StAX's getElementText does)
    public string ElementText()
    {
        if (Current != Kind.Element)
            throw new InvalidOperationException("parser must be on START_ELEMENT to read next text");
        if (pendingEnd) { pendingEnd = false; Current = Kind.EndElement; return ""; }
        var sb = new System.Text.StringBuilder();
        while (true)
        {
            if (!Advance()) throw new InvalidOperationException("unexpected end of document when reading element text content");
            var t = reader.NodeType;
            if (IsText(t)) { sb.Append(reader.Value); continue; }
            if (t == XmlNodeType.Comment || t == XmlNodeType.ProcessingInstruction) continue;
            if (t == XmlNodeType.EndElement)
            {
                Current = Kind.EndElement; CurrentName = reader.Name;
                return sb.ToString();
            }
            throw new InvalidOperationException("element text expected, but a child element was found");
        }
    }

    // An attribute of the current element by its qualified or local name
    public string? Attribute(string name)
    {
        if (Current != Kind.Element) return null;
        string? found = null;
        if (reader.MoveToFirstAttribute())
        {
            do
            {
                if (reader.Name == name || reader.LocalName == name) { found = reader.Value; break; }
            } while (reader.MoveToNextAttribute());
            reader.MoveToElement();
        }
        return found;
    }

    public void Close() { reader.Close(); reader.Dispose(); }
}
