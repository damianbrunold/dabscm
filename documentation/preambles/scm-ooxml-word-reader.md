## Overview

`(scm ooxml word-reader)` reads the text content of Word documents in the OOXML
(`.docx`) format — the counterpart to `(scm ooxml word)`. Open a document, get
its paragraphs and their text, and inspect styles and heading levels.

## Common uses

```scheme
(import (scm ooxml word-reader))

(define doc (read-document "letter.docx"))

(document-text doc)         ;; => the whole document as text
(document-paragraphs doc)   ;; => the paragraphs
(document-headings doc)     ;; => the heading paragraphs
```

Per-paragraph accessors include `paragraph-text`, `paragraph-style`,
`paragraph-heading-level`, and `paragraph-in-table?`.
`read-document-from-bytevector` reads from in-memory bytes.
