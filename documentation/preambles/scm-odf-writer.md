## Overview

`(scm odf writer)` creates text documents in the OpenDocument (`.odt`) format. Its
API mirrors `(scm ooxml word)`: build a document, add paragraphs and styled text
runs, apply styles, and save.

## Common uses

```scheme
(import (scm odf writer))

(define doc (make-document))
(define p (document-add-paragraph! doc))
(paragraph-add-run! p "Hello, ")
(paragraph-add-run! p "world" bold size: 14)

(document-save doc "letter.odt")
```

`paragraph-add-run!` accepts the same optional formatting as the Word writer
(`font:`, `size:`, `color:`, `bold`, `italic`, `underline`). Define reusable
styles with `document-define-style!` / `document-add-named-style!`, and use
`document-save-to-bytevector` for in-memory bytes.
