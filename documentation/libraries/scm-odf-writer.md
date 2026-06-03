# `(scm odf writer)`

ODF text document creation (ODT format)

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


## Exports

### `call-with-document`

```
Syntax: (call-with-document filename proc)
Library: (scm odf writer)
Description: Creates a new document, calls (proc doc), then saves to filename.
  Returns 'ok.
Example:
  (call-with-document "/tmp/out.odt"
    (lambda (doc)
      (let ((p (document-add-paragraph! doc)))
        (paragraph-add-run! p "Hello"))))
```

### `document-add-heading!`

```
Syntax: (document-add-heading! doc level [text])
Library: (scm odf writer)
Description: Adds a heading paragraph at the given outline level (1-6). Returns
  the new paragraph object. If text is provided, it is added as an unstyled run.
Example:
  (document-add-heading! doc 1 "Introduction")
```

### `document-add-index!`

```
Syntax: (document-add-index! doc [title])
Library: (scm odf writer)
Description: Adds an alphabetical index placeholder to the document. The index
  is updated by LibreOffice on open. title defaults to "Index". Use
  paragraph-add-index-entry! to mark terms for the index.
Example:
  (document-add-index! doc)
  (document-add-index! doc "Alphabetical Index")
```

### `document-add-named-style!`

```
Syntax: (document-add-named-style! doc name based-on font-name font-size color bold italic underline alignment spacing-before spacing-after line-spacing)
Library: (scm odf writer)
Description: Low-level function to add a named paragraph style to doc. All
  spacing values are in points (ODF uses pt natively). Use document-define-style!
  for a more convenient keyword-based interface.
Example:
  (document-add-named-style! doc "Heading" #f "Arial" 16 #f #t #f #f 'center 24 12 #f)
```

### `document-add-page-break!`

```
Syntax: (document-add-page-break! doc)
Library: (scm odf writer)
Description: Adds a page break to doc by inserting an empty paragraph with the
  page-break-before property set.
Example:
  (document-add-page-break! doc)
```

### `document-add-paragraph!`

```
Syntax: (document-add-paragraph! doc [style-name])
Library: (scm odf writer)
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
Library: (scm odf writer)
Description: Adds a table of contents placeholder to the document. The TOC is
  updated by LibreOffice on open. title defaults to "Table of Contents" and
  max-level defaults to 3.
Example:
  (document-add-table-of-contents! doc)
  (document-add-table-of-contents! doc "Contents" 2)
```

### `document-define-style!`

```
Syntax: (document-define-style! doc name [based-on: s] [font: n] [size: n] [color: c] [bold] [italic] [underline] [alignment: a] [spacing-before: n] [spacing-after: n] [line-spacing: n])
Library: (scm odf writer)
Description: Defines a named paragraph style in doc. Keyword arguments set font,
  size, color, bold/italic/underline flags, alignment, and spacing (in points).
  Unlike the Word library, spacing values are stored in points directly since
  ODF uses pt natively.
Example:
  (document-define-style! doc "Heading" font: "Arial" size: 16 bold alignment: 'center)
```

### `document-save`

```
Syntax: (document-save doc filename)
Library: (scm odf writer)
Description: Serializes doc to an ODF text document (.odt) file at filename.
  Returns 'ok.
Example:
  (let* ((doc (make-document))
         (p   (document-add-paragraph! doc)))
    (paragraph-add-run! p "Hello, World!")
    (document-save doc "/tmp/out.odt"))
```

### `document-save-to-bytevector`

```
Syntax: (document-save-to-bytevector doc)
Library: (scm odf writer)
Description: Serializes doc to an ODF text document in memory and returns the
  bytes as a bytevector. Useful for generating documents for HTTP responses or
  in-memory processing without writing to disk.
Example:
  (let* ((doc (make-document))
         (p   (document-add-paragraph! doc)))
    (paragraph-add-run! p "Hello, World!")
    (document-save-to-bytevector doc))
```

### `document-set-footer!`

```
Syntax: (document-set-footer! doc para ...)
Library: (scm odf writer)
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
Library: (scm odf writer)
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
Library: (scm odf writer)
Description: Sets the page size for the document. size may be a symbol
  (letter, a4, a5, legal) or a pair (width-cm-string . height-cm-string).
Example:
  (document-set-page-size! doc 'a5)
  (document-set-page-size! doc '("14.80cm" . "21.00cm"))
```

### `make-document`

```
Syntax: (make-document)
Library: (scm odf writer)
Description: Creates and returns a new empty ODF text document object.
Example:
  (let ((doc (make-document)))
    (document-add-paragraph! doc)
    (document-save doc "out.odt"))
```

### `make-run-style`

```
Syntax: (make-run-style)
Library: (scm odf writer)
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
Library: (scm odf writer)
Description: Adds a line break to para.
Example:
  (paragraph-add-break! para)
```

### `paragraph-add-image!`

```
Syntax: (paragraph-add-image! para filename width-pt height-pt)
Library: (scm odf writer)
Description: Embeds an image from filename into para. width-pt and height-pt
  are the display dimensions in points, which are converted to cm for ODF.
Example:
  (paragraph-add-image! para "logo.png" 100 50)
```

### `paragraph-add-index-entry!`

```
Syntax: (paragraph-add-index-entry! para term)
Library: (scm odf writer)
Description: Marks an inline index entry in para. term is the text that will
  appear in the alphabetical index. The mark is invisible in the document body.
Example:
  (paragraph-add-run! para "Scheme is a programming language.")
  (paragraph-add-index-entry! para "Scheme")
```

### `paragraph-add-page-number!`

```
Syntax: (paragraph-add-page-number! para)
Library: (scm odf writer)
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
Library: (scm odf writer)
Description: Adds a text run to para with optional formatting. Keyword arguments
  set font name, size (points), color (symbol or ARGB string), and style flags.
Example:
  (paragraph-add-run! para "hello")
  (paragraph-add-run! para "bold red" bold color: 'red)
```

### `paragraph-add-styled-run!`

```
Syntax: (paragraph-add-styled-run! para text run-style-or-false)
Library: (scm odf writer)
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
Library: (scm odf writer)
Description: Adds a tab character to para.
Example:
  (paragraph-add-tab! para)
```

### `paragraph-set-alignment!`

```
Syntax: (paragraph-set-alignment! para alignment)
Library: (scm odf writer)
Description: Sets the alignment of para. alignment is one of 'left 'center
  'right 'justify.
Example:
  (paragraph-set-alignment! para 'center)
```

### `paragraph-set-indent!`

```
Syntax: (paragraph-set-indent! para left-pt [right-pt [first-pt]])
Library: (scm odf writer)
Description: Sets paragraph indentation in points. Values are stored directly
  in points for ODF output.
Example:
  (paragraph-set-indent! para 36)
  (paragraph-set-indent! para 18 0 -18)
```

### `paragraph-set-page-break-before!`

```
Syntax: (paragraph-set-page-break-before! para)
Library: (scm odf writer)
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
Library: (scm odf writer)
Description: Sets paragraph spacing in points. ODF stores point values
  directly (no conversion needed). line-pt is optional line height.
Example:
  (paragraph-set-spacing! para 12 6)
  (paragraph-set-spacing! para 0 0 14)
```

### `paragraph-set-style!`

```
Syntax: (paragraph-set-style! para style-name)
Library: (scm odf writer)
Description: Sets the named style of para. style-name is a string matching a
  style defined with document-define-style!.
Example:
  (paragraph-set-style! para "Heading1")
```

### `paragraph-set-tab-stops!`

```
Syntax: (paragraph-set-tab-stops! para stops)
Library: (scm odf writer)
Description: Sets tab stops for para. stops is a list of (pos-pt alignment)
  where pos-pt is in points and alignment is a symbol ('left 'center 'right
  'decimal). Points are converted to cm for ODF output.
Example:
  (paragraph-set-tab-stops! para '((72 left) (144 center)))
```

### `register-color!`

```
Syntax: (register-color! name hex-string)
Library: (scm odf writer)
Description: Registers a new named color. name is a symbol; hex-string is an
  8-character ARGB hex string (e.g. "FFFF0000").
Example:
  (register-color! 'salmon "FFFA8072")
```

### `resolve-color`

```
Syntax: (resolve-color color)
Library: (scm odf writer)
Description: Resolves a color to an 8-character ARGB hex string. color may be
  a string (returned as-is) or a named symbol (black, white, red, etc.).
Example:
  (resolve-color 'red)       => "FFFF0000"
  (resolve-color "FFAABBCC") => "FFAABBCC"
```

