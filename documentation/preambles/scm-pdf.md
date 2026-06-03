## Overview

`(scm pdf)` creates PDF documents from scratch: add pages, draw vector paths and
shapes, set fonts (including embedded TrueType), place text and images, and add
links and outline bookmarks. You build a document, append pages, draw on them,
and serialize the result to a bytevector or file.

## Common uses

A minimal document:

```scheme
(import (scm pdf))

(define doc (make-pdf))
(pdf-add-page! doc)          ;; A4 by default
(pdf-save doc "blank.pdf")
```

Draw some text:

```scheme
(define doc (make-pdf))
(define page (pdf-add-page! doc pdf-page-size-letter))
(define helv (pdf-use-font doc 'helvetica))
(pdf-draw-text page helv 12 100 700 "Hello, world!")   ;; baseline at (100,700)
(pdf-save doc "hello.pdf")
```

Coordinates are in points with the origin at the bottom-left. There is a full
path/painting API (`pdf-move-to`, `pdf-line-to`, `pdf-rect`, `pdf-stroke`,
`pdf-fill`, …), `pdf-flow-text` for wrapped paragraphs, plus image, link, and
outline support. Use `pdf->bytevector` to get the document as bytes instead of
writing a file.
