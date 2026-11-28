# `(scm xml)`

XML file reading and navigation

## Overview

`(scm xml)` is a streaming (pull) XML reader. You open a reader over a file,
string, or bytevector, then call `xml-read` to advance node by node, querying the
current node's type, name, value, and attributes as you go. This keeps memory use
low for large documents.

## Common uses

```scheme
(import (scm xml))

(define r (open-xml-string "<a x=\"1\"><b>hi</b></a>"))

(xml-read r)          ;; advance to the next node => #t (or #f at end)
(xml-node-type r)     ;; => element
(xml-name r)          ;; => "a"
(xml-attribute r "x") ;; => "1"
```

## The event stream

The three implementations produce the same nodes:

- `element` and `end-element`, also for an empty element such as `<br/>`;
- `text`: one node per run of character data, with character references
  (`&amp;`) and CDATA sections merged into it (a comment splits it);
- `comment` and `pi` (processing instruction).

The XML declaration, a doctype and white space outside the root element give
no nodes; DTDs are not processed and external entities are never loaded.
After the root element's end (and trailing comments), `xml-read` returns `#f`.

`xml-name` is the qualified name (`"ns:item"`) of an element or end element,
`""` otherwise; `xml-read-to` and `xml-attribute` accept the qualified or the
local name. `xml-value` reads the text of the current element and leaves the
reader on its end, so the next `xml-read-to` finds the following sibling.

Drive it in a loop until `xml-read` returns `#f`. `xml-value` reads text content,
`xml-read-to` skips ahead to a named element, and `close-xml` releases the reader.
Open from a file or bytes with `open-xml-file` / `open-xml-bytevector`.


## Exports

### `close-xml`

```
Syntax: (close-xml reader)
Library: (scm core)
Description: Closes the given XML reader, releasing any underlying file or stream resources.
Example:
  (let ((r (open-xml-file "data.xml")))
    (close-xml r))
```

### `open-xml-bytevector`

```
Syntax: (open-xml-bytevector bv)
Library: (scm xml)
Description: Opens the XML document encoded in the given bytevector and returns an XML reader for forward-only reading of XML nodes. The byte stream is decoded using the XML declaration's encoding, defaulting to UTF-8.
Example:
  (define r (open-xml-bytevector (string->utf8 "<a/>")))
  (xml-node-type r) => element
```

### `open-xml-file`

```
Syntax: (open-xml-file filename)
Library: (scm core)
Description: Opens the named XML file and returns an XML reader object for forward-only reading of XML nodes.
Example:
  (define r (open-xml-file "data.xml"))
  (xml-node-type r) => node-type of first node
```

### `open-xml-string`

```
Syntax: (open-xml-string source)
Library: (scm xml)
Description: Opens the given XML string and returns an XML reader object for forward-only reading of XML nodes.
Example:
  (define r (open-xml-string "<a/>"))
  (xml-node-type r) => element
```

### `xml-attribute`

```
Syntax: (xml-attribute xml-reader name)
Library: (scm xml)
Description: Returns the value of the attribute with the given qualified or local name of the current element as a string, or #f if the attribute does not exist or the current node is not an element.
Example:
  (xml-attribute reader "id") => "42"
  (xml-attribute reader 'class) => #f
```

### `xml-name`

```
Syntax: (xml-name xml-reader)
Library: (scm xml)
Description: Returns the qualified name (prefix:local) of the current element or end-element node as a string, "" for other nodes.
Example:
  (xml-name reader) => "Customer"
  (xml-name reader) => "ns:Element"
```

### `xml-node-type`

```
Syntax: (xml-node-type xml-reader)
Library: (scm xml)
Description: Returns a symbol for the current node: element, end-element (also after an empty element such as <br/>), text (one node per run of character data, with character references and CDATA sections merged), comment or pi; #f before the first xml-read and at the end.
Example:
  (xml-node-type reader) => element
  (xml-node-type reader) => text
```

### `xml-read`

```
Syntax: (xml-read xml-reader)
Library: (scm xml)
Description: Advances xml-reader to the next node and returns #t, or #f at the end of the document. The XML declaration, a doctype and white space outside the root element are skipped.
Example:
  (xml-read reader) => #t
  (xml-read reader) => #f
```

### `xml-read-to`

```
Syntax: (xml-read-to xml-reader name)
Library: (scm xml)
Description: Advances xml-reader forward until it reaches an element whose qualified or local name is name (a string or symbol). Returns #t if found, or #f if the end of the document is reached first.
Example:
  (xml-read-to reader "Customer") => #t
  (xml-read-to reader 'Item) => #f
```

### `xml-value`

```
Syntax: (xml-value xml-reader)
Library: (scm xml)
Description: Reads the text content of the current element (which must contain no child elements) and returns it as a string, "" for an empty element. The reader is left on the element's end-element node.
Example:
  (xml-value reader) => "John Doe"
```

