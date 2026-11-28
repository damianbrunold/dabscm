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
