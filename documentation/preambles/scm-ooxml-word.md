## Overview

`(scm ooxml word)` creates Word documents in the OOXML (`.docx`) format. Build a
document, add paragraphs and styled text runs, apply named or inline styles, add
tables/images/headings, and save. To read existing documents, see
`(scm ooxml word-reader)`. (This is the library that renders this project's own
`reference.docx`.)

## Common uses

```scheme
(import (scm ooxml word))

(define doc (make-document))
(define p (document-add-paragraph! doc))
(paragraph-add-run! p "Hello, " )
(paragraph-add-run! p "world" bold size: 14)

(document-save doc "letter.docx")
```

`paragraph-add-run!` takes optional formatting: `font:`, `size:`, `color:`, and
the flags `bold`, `italic`, `underline`. Headings come from
`document-add-heading!`, reusable styles from `document-define-style!`, and
`document-save-to-bytevector` returns the file as bytes.
