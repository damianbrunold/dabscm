# `(scm ooxml word)`

Word document creation (OOXML/DOCX format)

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


## Exports

### `call-with-document`

```
Syntax: (call-with-document filename proc)
Library: (scm ooxml word)
Description: Creates a new document, calls (proc doc), then saves to filename.
Returns 'ok.
Example:
  (call-with-document "/tmp/out.docx"
    (lambda (doc)
      (let ((p (document-add-paragraph! doc)))
        (paragraph-add-run! p "Hello"))))
```

### `document-add-heading!`

```
Syntax: (document-add-heading! doc level [text])
Library: (scm ooxml word)
Description: Adds a heading paragraph at the given outline level (1-6). Returns
the new paragraph object. If text is provided, it is added as an unstyled run.
Example:
  (document-add-heading! doc 1 "Introduction")
```

### `document-add-index!`

```
Syntax: (document-add-index! doc [title])
Library: (scm ooxml word)
Description: Adds an alphabetical index placeholder to the document. The index
is a field code that Word/LibreOffice updates on open. title defaults to
"Index". Use paragraph-add-index-entry! to mark terms for the index.
Example:
  (document-add-index! doc)
  (document-add-index! doc "Alphabetical Index")
```

### `document-add-named-style!`

*(no documentation)*

### `document-add-page-break!`

```
Syntax: (document-add-page-break! doc)
Library: (scm ooxml word)
Description: Adds a page break to doc by inserting an empty paragraph with the
page-break-before property set.
Example:
  (document-add-page-break! doc)
```

### `document-add-paragraph!`

```
Syntax: (document-add-paragraph! doc [style-name])
Library: (scm ooxml word)
Description: Adds a new paragraph to doc, optionally with a named style.
Returns the new paragraph object.
Example:
  (let* ((doc (make-document))
         (p (document-add-paragraph! doc "Heading1")))
    (paragraph-add-run! p "Title"))
```

### `document-add-table-of-contents!`

```
Syntax: (document-add-table-of-contents! doc [title [max-level]])
Library: (scm ooxml word)
Description: Adds a table of contents placeholder to the document. The TOC is
a field code that Word/LibreOffice updates on open. title defaults to
"Table of Contents" and max-level defaults to 3.
Example:
  (document-add-table-of-contents! doc)
  (document-add-table-of-contents! doc "Contents" 2)
```

### `document-define-style!`

```
Syntax: (document-define-style! doc name [based-on: s] [font: n] [size: n] [color: c] [bold] [italic] [underline] [alignment: a] [spacing-before: n] [spacing-after: n] [line-spacing: n])
Library: (scm ooxml word)
Description: Defines a named paragraph style in doc. Keyword arguments set font,
size, color, bold/italic/underline flags, alignment, and spacing (in points).
Example:
  (document-define-style! doc "Heading" font: "Arial" size: 16 bold alignment: 'center)
```

### `document-save`

```
Syntax: (document-save doc filename)
Library: (scm ooxml word)
Description: Serializes doc to a DOCX file at filename. Returns 'ok.
Example:
  (let* ((doc (make-document))
         (p   (document-add-paragraph! doc)))
    (paragraph-add-run! p "Hello, World!")
    (document-save doc "/tmp/out.docx"))
```

### `document-save-to-bytevector`

```
Syntax: (document-save-to-bytevector doc)
Library: (scm ooxml word)
Description: Serializes doc to a DOCX file in memory and returns the bytes as
a bytevector. Useful for generating documents for HTTP responses or in-memory
processing without writing to disk.
Example:
  (let* ((doc (make-document))
         (p   (document-add-paragraph! doc)))
    (paragraph-add-run! p "Hello, World!")
    (document-save-to-bytevector doc))
```

### `document-set-footer!`

```
Syntax: (document-set-footer! doc para ...)
Library: (scm ooxml word)
Description: Sets the document footer to the given paragraph(s). The paragraphs
should be created with document-add-paragraph! and can contain runs, page
numbers, and other inline content.
Example:
  (let ((p (document-add-paragraph! doc)))
    (paragraph-set-alignment! p 'center)
    (paragraph-add-page-number! p)
    (document-set-footer! doc p))
```

### `document-set-header!`

```
Syntax: (document-set-header! doc para ...)
Library: (scm ooxml word)
Description: Sets the document header to the given paragraph(s). The paragraphs
should be created with document-add-paragraph! and can contain runs, page
numbers, and other inline content.
Example:
  (let ((p (document-add-paragraph! doc)))
    (paragraph-set-alignment! p 'right)
    (paragraph-add-run! p "My Document" italic size: 8)
    (document-set-header! doc p))
```

### `document-set-page-size!`

```
Syntax: (document-set-page-size! doc size)
Library: (scm ooxml word)
Description: Sets the page size for the document. size may be a symbol
(letter, a4, a5, legal) or a pair (width-twips . height-twips).
Example:
  (document-set-page-size! doc 'a5)
  (document-set-page-size! doc '(8391 . 11906))
```

### `make-document`

```
Syntax: (make-document)
Library: (scm ooxml word)
Description: Creates and returns a new empty Word document object.
Example:
  (let ((doc (make-document)))
    (document-add-paragraph! doc)
    (document-save doc "out.docx"))
```

### `make-run-style`

```
Syntax: (make-run-style)
Library: (scm ooxml word)
Description: Creates a mutable run style object (font-name, font-size, bold,
italic, underline, color). Use paragraph-add-styled-run! to apply it.
Example:
  (let ((rs (make-run-style)))
    (rs 'set-bold #t)
    (rs 'set-color (resolve-color 'red))
    (paragraph-add-styled-run! para "text" rs))
```

### `paragraph-add-break!`

```
Syntax: (paragraph-add-break! para)
Library: (scm ooxml word)
Description: Adds a line break (w:br) to para.
Example:
  (paragraph-add-break! para)
```

### `paragraph-add-image!`

```
Syntax: (paragraph-add-image! para filename width-pt height-pt)
Library: (scm ooxml word)
Description: Embeds an image from filename into para. width-pt and height-pt
are the display dimensions in points (1 pt = 12700 EMU).
Example:
  (paragraph-add-image! para "logo.png" 100 50)
```

### `paragraph-add-index-entry!`

```
Syntax: (paragraph-add-index-entry! para term)
Library: (scm ooxml word)
Description: Marks an inline index entry in para. term is the text that will
appear in the alphabetical index. The mark is invisible in the document body.
Example:
  (paragraph-add-run! para "Scheme is a programming language.")
  (paragraph-add-index-entry! para "Scheme")
```

### `paragraph-add-page-number!`

```
Syntax: (paragraph-add-page-number! para)
Library: (scm ooxml word)
Description: Adds a page number field to the paragraph. The page number is
automatically updated when the document is rendered.
Example:
  (let ((p (document-add-paragraph! doc)))
    (paragraph-add-run! p "Page ")
    (paragraph-add-page-number! p))
```

### `paragraph-add-run!`

```
Syntax: (paragraph-add-run! para text [font: n] [size: n] [color: c] [bold] [italic] [underline])
Library: (scm ooxml word)
Description: Adds a text run to para with optional formatting. Keyword arguments
set font name, size (points), color (symbol or ARGB string), and style flags.
Example:
  (paragraph-add-run! para "hello")
  (paragraph-add-run! para "bold red" bold color: 'red)
```

### `paragraph-add-styled-run!`

```
Syntax: (paragraph-add-styled-run! para text run-style-or-false)
Library: (scm ooxml word)
Description: Adds a text run to para. run-style-or-false is a run style object
from make-run-style, or #f for unstyled text.
Example:
  (paragraph-add-styled-run! para "hello" #f)
  (let ((rs (make-run-style))) (rs 'set-bold #t)
    (paragraph-add-styled-run! para "bold" rs))
```

### `paragraph-add-tab!`

```
Syntax: (paragraph-add-tab! para)
Library: (scm ooxml word)
Description: Adds a tab character to para.
Example:
  (paragraph-add-tab! para)
```

### `paragraph-set-alignment!`

```
Syntax: (paragraph-set-alignment! para alignment)
Library: (scm ooxml word)
Description: Sets the alignment of para. alignment is one of 'left 'center
'right 'justify.
Example:
  (paragraph-set-alignment! para 'center)
```

### `paragraph-set-indent!`

```
Syntax: (paragraph-set-indent! para left-pt [right-pt [first-pt]])
Library: (scm ooxml word)
Description: Sets paragraph indentation in points (converted to twips).
Example:
  (paragraph-set-indent! para 1.0)
  (paragraph-set-indent! para 0.5 0 -0.5)
```

### `paragraph-set-page-break-before!`

```
Syntax: (paragraph-set-page-break-before! para)
Library: (scm ooxml word)
Description: Sets the page-break-before property on para so that it starts on
a new page when rendered.
Example:
  (let ((p (document-add-paragraph! doc)))
    (paragraph-set-page-break-before! p)
    (paragraph-add-run! p "New page content"))
```

### `paragraph-set-spacing!`

```
Syntax: (paragraph-set-spacing! para before-pt after-pt [line-pt])
Library: (scm ooxml word)
Description: Sets paragraph spacing. Values are in points and are converted
to twips internally (1 pt = 20 twips). line-pt is optional.
Example:
  (paragraph-set-spacing! para 12 6)
  (paragraph-set-spacing! para 0 0 14)
```

### `paragraph-set-style!`

```
Syntax: (paragraph-set-style! para style-name)
Library: (scm ooxml word)
Description: Sets the named style of para. style-name is a string matching a
style defined with document-define-style! or a built-in Word style.
Example:
  (paragraph-set-style! para "Heading1")
```

### `paragraph-set-tab-stops!`

```
Syntax: (paragraph-set-tab-stops! para stops)
Library: (scm ooxml word)
Description: Sets tab stops for para. stops is a list of (pos-pt alignment)
where pos-pt is in points and alignment is a symbol ('left 'center 'right
'decimal). Points are converted to twips.
Example:
  (paragraph-set-tab-stops! para '((2.5 left) (5.0 center)))
```

### `register-color!`

```
Syntax: (register-color! name hex-string)
Library: (scm ooxml word)
Description: Registers a new named color. name is a symbol; hex-string is an
8-character ARGB hex string (e.g. "FFFF0000").
Example:
  (register-color! 'salmon "FFFA8072")
```

### `resolve-color`

```
Syntax: (resolve-color color)
Library: (scm ooxml word)
Description: Resolves a color to an 8-character ARGB hex string. color may be
a string (returned as-is) or a named symbol (black, white, red, etc.).
Example:
  (resolve-color 'red)       => "FFFF0000"
  (resolve-color "FFAABBCC") => "FFAABBCC"
```

