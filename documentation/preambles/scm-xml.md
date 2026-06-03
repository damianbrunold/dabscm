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

Drive it in a loop until `xml-read` returns `#f`. `xml-value` reads text content,
`xml-read-to` skips ahead to a named element, and `close-xml` releases the reader.
Open from a file or bytes with `open-xml-file` / `open-xml-bytevector`.
