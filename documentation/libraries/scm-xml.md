# `(scm xml)`

XML file reading and navigation

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

### `open-xml-file`

```
Syntax: (open-xml-file filename)
Library: (scm core)
Description: Opens the named XML file and returns an XML reader object for forward-only reading of XML nodes.
Example:
  (define r (open-xml-file "data.xml"))
  (xml-node-type r) => node-type of first node
```

### `xml-attribute`

```
Syntax: (xml-attribute xml-reader name)
Library: (scm xml)
Description: Returns the value of the named attribute from the current element of xml-reader as a string, or #f if the attribute does not exist.
Example:
  (xml-attribute reader "id") => "42"
  (xml-attribute reader 'class) => #f
```

### `xml-name`

```
Syntax: (xml-name xml-reader)
Library: (scm xml)
Description: Returns the qualified name of the current XML element or attribute node as a string.
Example:
  (xml-name reader) => "Customer"
  (xml-name reader) => "ns:Element"
```

### `xml-node-type`

```
Syntax: (xml-node-type xml-reader)
Library: (scm xml)
Description: Returns a symbol identifying the type of the current XML node: element, end-element, text, cdata, comment, pi, xml-decl, doc, doc-type, entity-ref, or #f for unrecognized types.
Example:
  (xml-node-type reader) => element
  (xml-node-type reader) => text
```

### `xml-read`

```
Syntax: (xml-read xml-reader)
Library: (scm xml)
Description: Advances xml-reader to the next node in the XML document. Returns #t if a node was read, or #f if the end of the document was reached.
Example:
  (xml-read reader) => #t
  (xml-read reader) => #f
```

### `xml-read-to`

```
Syntax: (xml-read-to xml-reader name)
Library: (scm xml)
Description: Advances xml-reader forward until it reaches an element with the given name. Returns #t if found, or #f if the end of the document is reached first.
Example:
  (xml-read-to reader "Customer") => #t
  (xml-read-to reader 'Item) => #f
```

### `xml-value`

```
Syntax: (xml-value xml-reader)
Library: (scm xml)
Description: Reads and returns the text content of the current element as a string, or #f if there is no value.
Example:
  (xml-value reader) => "John Doe"
  (xml-value reader) => #f
```

