# `(scm pdf)`

PDF document creation — pages, drawing, fonts, text flow, TTF embedding, images, links, outlines

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


## Exports

### `make-pdf`

```
Syntax: (make-pdf)
Library: (scm pdf)
Description: Creates a new empty PDF document. Pages are appended with
  pdf-add-page! and the finished document is serialized with pdf-save
  or pdf->bytevector.
Example:
  (define doc (make-pdf))
  (pdf-add-page! doc)
  (pdf-save doc "blank.pdf")
```

### `pdf->bytevector`

```
Syntax: (pdf->bytevector doc)
Library: (scm pdf)
Description: Serializes doc to a bytevector containing a complete PDF
  file (header, all objects, xref table, trailer, %%EOF). Pages with
  no content render as blank pages of the requested size.
Example:
  (define doc (make-pdf))
  (pdf-add-page! doc)
  (pdf->bytevector doc)
```

### `pdf-add-link`

```
Syntax: (pdf-add-link page rect uri-string)
Library: (scm pdf)
Description: Attaches a clickable URI link annotation to page. rect is
  a 4-element list (llx lly urx ury) of user-space coordinates marking
  the hot area; uri-string is the absolute URL to open. The annotation
  has no visible border.
Example:
  (pdf-draw-text page helv 12 100 700 "Click here")
  (pdf-add-link page '(100 695 200 712) "https://example.com")
```

### `pdf-add-outline!`

```
Syntax: (pdf-add-outline! doc page title [option value]...)
Library: (scm pdf)
Description: Appends an outline (bookmark) entry that jumps to page.
  Options (plist):
    parent  another outline returned by pdf-add-outline! — creates a
            nested child under that outline (default: top-level item)
    y       baseline y-coord to scroll the page to (default: page top)
  Returns the outline handle so it can be used as a parent in later
  calls.
Example:
  (define ch1 (pdf-add-outline! doc page1 "Chapter 1"))
  (pdf-add-outline! doc page1 "Section 1.1" 'parent ch1)
```

### `pdf-add-page!`

```
Syntax: (pdf-add-page! doc)
       (pdf-add-page! doc size-pair)
       (pdf-add-page! doc width-pt height-pt)
Library: (scm pdf)
Description: Appends a new page to doc and returns the page record.
  With no extra arguments the page is A4 (595x842 points). A size pair
  is a (cons width height); the page-size presets (pdf-page-size-a4
  etc.) are such pairs. Or pass explicit width and height in points.
Example:
  (pdf-add-page! doc)                       ; A4
  (pdf-add-page! doc pdf-page-size-letter)  ; US Letter
  (pdf-add-page! doc 200 100)               ; custom size
```

### `pdf-array?`

*(no documentation)*

### `pdf-clip`

```
Syntax: (pdf-clip page)
Library: (scm pdf)
Description: Modifies the current clipping path by intersecting it with
  the current path (non-zero rule). Per the PDF spec this must be
  followed by a painting or pdf-end-path operator. Emits 'W'.
Example: (pdf-rect page 0 0 100 100) (pdf-clip page) (pdf-end-path page)
```

### `pdf-clip-even-odd`

```
Syntax: (pdf-clip-even-odd page)
Library: (scm pdf)
Description: Like pdf-clip but uses the even-odd rule. Emits 'W*'.
Example: (pdf-clip-even-odd page)
```

### `pdf-close-path`

```
Syntax: (pdf-close-path page)
Library: (scm pdf)
Description: Closes the current subpath with a straight line back to its
  start. Emits the PDF 'h' operator.
Example: (pdf-close-path page)
```

### `pdf-close-stroke`

```
Syntax: (pdf-close-stroke page)
Library: (scm pdf)
Description: Closes and strokes the current path. Emits 's'.
Example: (pdf-close-stroke page)
```

### `pdf-curve-to`

```
Syntax: (pdf-curve-to page cx1 cy1 cx2 cy2 x y)
Library: (scm pdf)
Description: Appends a cubic Bezier curve from the current point to
  (x, y) using control points (cx1, cy1) and (cx2, cy2). Emits 'c'.
Example: (pdf-curve-to page 100 100 200 200 300 100)
```

### `pdf-dict?`

*(no documentation)*

### `pdf-draw-image`

```
Syntax: (pdf-draw-image page image x y width height)
Library: (scm pdf)
Description: Places image on page at user-space coordinates (x, y) —
  the lower-left corner — scaled to width × height points. Image
  XObjects are defined in a 1×1 unit square, so this concatenates a
  scale+translate matrix and emits the Do operator. Wrapped in a
  q ... Q pair to localize state changes.
Example:
  (pdf-draw-image page logo 50 600 100 100)
```

### `pdf-draw-text`

```
Syntax: (pdf-draw-text page font size x y string)
Library: (scm pdf)
Description: Draws string on page at user-space coordinates (x, y) — the
  baseline origin — in font at size points. Emits a self-contained
  q ... BT ... ET ... Q block so any current graphics state is
  preserved. To rotate or scale text, wrap the call in pdf-with-state
  and concat your own CTM.
Example:
  (define helv (pdf-use-font doc 'helvetica))
  (pdf-draw-text page helv 12 100 700 "Hello, world!")
```

### `pdf-embed-jpeg`

```
Syntax: (pdf-embed-jpeg doc jpeg-bytevector)
Library: (scm pdf)
Description: Embeds a JPEG image in doc as an Image XObject using
  /Filter /DCTDecode (pass-through — no re-encoding). Auto-detects
  width, height and color space (gray / RGB / CMYK) from the JPEG's
  Start-Of-Frame marker. Returns a pdf-image handle for use with
  pdf-draw-image.
Example:
  (define j (pdf-embed-jpeg doc (pdf-read-binary-file "photo.jpg")))
  (pdf-draw-image page j 50 600 200 150)
```

### `pdf-embed-png`

```
Syntax: (pdf-embed-png doc png-bytevector)
Library: (scm pdf)
Description: Embeds a PNG image in doc as an Image XObject. The PNG's
  concatenated IDAT chunks are emitted verbatim as a /FlateDecode
  stream with /DecodeParms /Predictor 15 so the reader applies the
  PNG filter rules. Color types 0 (grayscale) and 2 (RGB) pass through
  the IDAT verbatim. Color types 4 (gray + alpha) and 6 (RGB + alpha)
  are fully decoded, then the color and alpha channels are emitted as
  two separate flate-compressed Image XObjects with the alpha as an
  /SMask. 8-bit depth only. Returns a pdf-image handle for use with
  pdf-draw-image.
Example:
  (define p (pdf-embed-png doc (pdf-read-binary-file "logo.png")))
  (pdf-draw-image page p 50 600 100 100)
```

### `pdf-embed-truetype-font`

```
Syntax: (pdf-embed-truetype-font doc ttf-bytes [base-name])
Library: (scm pdf)
Description: Parses the TrueType font in ttf-bytes (a bytevector, e.g.
  from pdf-read-binary-file), registers it on doc as an embedded Type0
  composite font with /Encoding /Identity-H, and returns a font handle
  usable with pdf-draw-text, pdf-text-width and pdf-flow-text. Supports
  the full Unicode BMP (cmap format 4) or beyond (format 12). The whole
  TTF is embedded — no subsetting; expect a few hundred KB per font.
  An optional base-name overrides the PostScript name used for the
  PDF /BaseFont entry (defaults to "EmbeddedTTF<n>").
Example:
  (define bv (pdf-read-binary-file "/path/to/DejaVuSans.ttf"))
  (define dj (pdf-embed-truetype-font doc bv "DejaVuSans"))
  (pdf-draw-text page dj 14 50 700 "Hello, мир, 日本語, ✓")
```

### `pdf-end-path`

```
Syntax: (pdf-end-path page)
Library: (scm pdf)
Description: Ends the current path without filling or stroking. Used
  after pdf-clip / pdf-clip-even-odd. Emits 'n'.
Example: (pdf-end-path page)
```

### `pdf-fill`

```
Syntax: (pdf-fill page)
Library: (scm pdf)
Description: Fills the current path using the non-zero winding rule.
  Emits the PDF 'f' operator.
Example: (pdf-fill page)
```

### `pdf-fill-and-stroke`

```
Syntax: (pdf-fill-and-stroke page)
Library: (scm pdf)
Description: Fills (non-zero) and strokes the current path. Emits 'B'.
Example: (pdf-fill-and-stroke page)
```

### `pdf-fill-and-stroke-even-odd`

```
Syntax: (pdf-fill-and-stroke-even-odd page)
Library: (scm pdf)
Description: Fills (even-odd) and strokes the current path. Emits 'B*'.
Example: (pdf-fill-and-stroke-even-odd page)
```

### `pdf-fill-even-odd`

```
Syntax: (pdf-fill-even-odd page)
Library: (scm pdf)
Description: Fills the current path using the even-odd rule. Emits 'f*'.
Example: (pdf-fill-even-odd page)
```

### `pdf-flow-text`

```
Syntax: (pdf-flow-text page font size rect text [option value]...)
Library: (scm pdf)
Description: Lays out text into a rectangular region using greedy word
  wrapping and the font's AFM widths. Returns two values via `values`:
  the leftover text (or "" if everything fit) and the y-coordinate
  where the next line would have been placed (useful for continuing
  below the block).
  rect is a 4-element list: (x y width height), where (x, y) is the
  rectangle's lower-left corner in user-space (PDF) points.
  Options (plist style):
    align    one of 'left (default), 'right, 'center, 'justify
    leading  line spacing in points (default: size * 1.2)
  Newline characters in text force hard line breaks; the line that ends
  at a hard break is never justified. Words wider than rect width are
  placed on a line by themselves (and will overflow horizontally).
Example:
  (define helv (pdf-use-font doc 'helvetica))
  (call-with-values
    (lambda () (pdf-flow-text page helv 11 '(72 72 200 400)
                              "Lorem ipsum dolor sit amet ..."
                              'align 'justify))
    (lambda (rest final-y)
      (when (not (string=? rest ""))
        ...flow rest into a second column...)))
```

### `pdf-font-ascender`

```
Syntax: (pdf-font-ascender font)
Library: (scm pdf)
Description: Returns the font's ascender height in 1/1000 em units
  (multiply by font size and divide by 1000 to get a user-space value).
Example: (pdf-font-ascender (pdf-use-font doc 'helvetica))
```

### `pdf-font-base-name`

*(no documentation)*

### `pdf-font-cap-height`

```
Syntax: (pdf-font-cap-height font)
Library: (scm pdf)
Description: Returns the font's capital-letter height in 1/1000 em
  units.
```

### `pdf-font-cmap-lookup`

*(no documentation)*

### `pdf-font-descender`

```
Syntax: (pdf-font-descender font)
Library: (scm pdf)
Description: Returns the font's descender depth in 1/1000 em units
  (a negative number for most fonts).
```

### `pdf-font-encoding`

*(no documentation)*

### `pdf-font-kind`

*(no documentation)*

### `pdf-font-num-glyphs`

*(no documentation)*

### `pdf-font-ttf-bytes`

*(no documentation)*

### `pdf-font-units-per-em`

*(no documentation)*

### `pdf-font-x-height`

```
Syntax: (pdf-font-x-height font)
Library: (scm pdf)
Description: Returns the font's x-height in 1/1000 em units.
```

### `pdf-font?`

*(no documentation)*

### `pdf-image-height`

*(no documentation)*

### `pdf-image-width`

*(no documentation)*

### `pdf-image?`

*(no documentation)*

### `pdf-line-cap-butt`

*(no documentation)*

### `pdf-line-cap-round`

*(no documentation)*

### `pdf-line-cap-square`

*(no documentation)*

### `pdf-line-join-bevel`

*(no documentation)*

### `pdf-line-join-miter`

*(no documentation)*

### `pdf-line-join-round`

*(no documentation)*

### `pdf-line-to`

```
Syntax: (pdf-line-to page x y)
Library: (scm pdf)
Description: Appends a straight line segment from the current point to
  (x, y). Emits the PDF 'l' operator.
Example: (pdf-line-to page 300 400)
```

### `pdf-move-to`

```
Syntax: (pdf-move-to page x y)
Library: (scm pdf)
Description: Begins a new subpath at (x, y). Emits the PDF 'm' operator.
Example: (pdf-move-to page 100 200)
```

### `pdf-name?`

*(no documentation)*

### `pdf-page-count`

```
Syntax: (pdf-page-count doc)
Library: (scm pdf)
Description: Returns the number of pages currently in doc.
Example: (pdf-page-count (make-pdf))  ; => 0
```

### `pdf-page-has-content?`

```
Syntax: (pdf-page-has-content? page)
Library: (scm pdf)
Description: True if any drawing operators have been emitted to page.
  Pages without content are written without a /Contents entry.
```

### `pdf-page-height`

*(no documentation)*

### `pdf-page-size-a4`

*(no documentation)*

### `pdf-page-size-a5`

*(no documentation)*

### `pdf-page-size-legal`

*(no documentation)*

### `pdf-page-size-letter`

*(no documentation)*

### `pdf-page-width`

*(no documentation)*

### `pdf-page?`

*(no documentation)*

### `pdf-read-binary-file`

```
Syntax: (pdf-read-binary-file path)
Library: (scm pdf)
Description: Convenience wrapper that opens path as a binary file,
  reads its full contents into a bytevector, and returns the bytevector.
  Intended for loading TTF files before calling pdf-embed-truetype-font.
Example:
  (pdf-read-binary-file "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
```

### `pdf-rect`

```
Syntax: (pdf-rect page x y width height)
Library: (scm pdf)
Description: Appends a complete rectangular subpath with its lower-left
  corner at (x, y). Emits the PDF 're' operator. No painting is done.
Example: (pdf-rect page 50 50 100 200)
```

### `pdf-ref?`

*(no documentation)*

### `pdf-restore-state`

```
Syntax: (pdf-restore-state page)
Library: (scm pdf)
Description: Pops the most recently saved graphics state. Emits 'Q'.
Example: (pdf-restore-state page)
```

### `pdf-rotate`

```
Syntax: (pdf-rotate page degrees)
Library: (scm pdf)
Description: Concatenates a rotation about the origin (in degrees,
  counter-clockwise) onto the CTM. Translate first to rotate about a
  different point.
Example:
  (pdf-with-state page
    (lambda ()
      (pdf-translate page 100 100)
      (pdf-rotate page 45)
      (pdf-rect page -25 -25 50 50)
      (pdf-stroke page)))
```

### `pdf-save`

```
Syntax: (pdf-save doc path)
Library: (scm pdf)
Description: Serializes doc with pdf->bytevector and writes the result
  to the file at path. Overwrites an existing file.
Example:
  (define doc (make-pdf))
  (pdf-add-page! doc)
  (pdf-save doc "blank.pdf")
```

### `pdf-save-state`

```
Syntax: (pdf-save-state page)
Library: (scm pdf)
Description: Pushes the current graphics state onto the stack (CTM,
  colors, line attributes, clip path). Emits the PDF 'q' operator. Must
  be paired with pdf-restore-state. Prefer pdf-with-state to keep them
  balanced.
Example: (pdf-save-state page)
```

### `pdf-scale`

```
Syntax: (pdf-scale page sx sy)
Library: (scm pdf)
Description: Concatenates an axis-aligned scale by (sx, sy) onto the CTM.
Example: (pdf-scale page 2 2)
```

### `pdf-set-dash`

```
Syntax: (pdf-set-dash page pattern-list phase)
Library: (scm pdf)
Description: Sets the dash pattern. pattern-list is a list of numbers
  alternating dash/gap lengths; an empty list resets to a solid line.
  phase is the offset into the pattern at which to start. Emits 'd'.
Example:
  (pdf-set-dash page '(5 3) 0)   ; 5-on 3-off
  (pdf-set-dash page '() 0)      ; solid
```

### `pdf-set-fill-cmyk`

```
Syntax: (pdf-set-fill-cmyk page c m y k)
Library: (scm pdf)
Description: Sets the non-stroking color to CMYK (each in [0, 1]).
  Emits 'k'.
Example: (pdf-set-fill-cmyk page 1 0 0 0)   ; cyan
```

### `pdf-set-fill-gray`

```
Syntax: (pdf-set-fill-gray page g)
Library: (scm pdf)
Description: Sets the non-stroking color to gray (g in [0, 1]).
  Emits 'g'.
Example: (pdf-set-fill-gray page 0.9)
```

### `pdf-set-fill-rgb`

```
Syntax: (pdf-set-fill-rgb page r g b)
Library: (scm pdf)
Description: Sets the non-stroking color to RGB (each in [0, 1]).
  Emits 'rg'.
Example: (pdf-set-fill-rgb page 0 0 1)   ; blue
```

### `pdf-set-line-cap`

```
Syntax: (pdf-set-line-cap page cap)
Library: (scm pdf)
Description: Sets the line cap style. cap is 0 (butt), 1 (round) or
  2 (projecting square) — see pdf-line-cap-butt etc. Emits 'J'.
Example: (pdf-set-line-cap page pdf-line-cap-round)
```

### `pdf-set-line-join`

```
Syntax: (pdf-set-line-join page join)
Library: (scm pdf)
Description: Sets the line join style. join is 0 (miter), 1 (round) or
  2 (bevel) — see pdf-line-join-miter etc. Emits 'j'.
Example: (pdf-set-line-join page pdf-line-join-round)
```

### `pdf-set-line-width`

```
Syntax: (pdf-set-line-width page width)
Library: (scm pdf)
Description: Sets the line width in user units. Emits 'w'.
Example: (pdf-set-line-width page 1.5)
```

### `pdf-set-metadata!`

```
Syntax: (pdf-set-metadata! doc key1 value1 key2 value2 ...)
Library: (scm pdf)
Description: Sets document metadata fields on the /Info dictionary.
  Repeated keys overwrite earlier values. Recognised keys (symbols):
    title author subject keywords creator producer
    creation-date mod-date
  Values are strings. Date strings should follow PDF format,
  e.g. "D:20260527120000+02'00".
Example:
  (pdf-set-metadata! doc 'title "My Report"
                         'author "Damian"
                         'creator "(scm pdf)")
```

### `pdf-set-miter-limit`

```
Syntax: (pdf-set-miter-limit page miter-limit)
Library: (scm pdf)
Description: Sets the miter limit. Emits 'M'.
Example: (pdf-set-miter-limit page 10)
```

### `pdf-set-stroke-cmyk`

```
Syntax: (pdf-set-stroke-cmyk page c m y k)
Library: (scm pdf)
Description: Sets the stroking color to CMYK (each in [0, 1]).
  Emits 'K'.
Example: (pdf-set-stroke-cmyk page 0 1 1 0)   ; pure red
```

### `pdf-set-stroke-gray`

```
Syntax: (pdf-set-stroke-gray page g)
Library: (scm pdf)
Description: Sets the stroking color to gray (g in [0, 1]). Emits 'G'.
Example: (pdf-set-stroke-gray page 0.5)
```

### `pdf-set-stroke-rgb`

```
Syntax: (pdf-set-stroke-rgb page r g b)
Library: (scm pdf)
Description: Sets the stroking color to RGB (each in [0, 1]).
  Emits 'RG'.
Example: (pdf-set-stroke-rgb page 1 0 0)   ; red
```

### `pdf-stream?`

*(no documentation)*

### `pdf-stroke`

```
Syntax: (pdf-stroke page)
Library: (scm pdf)
Description: Strokes the current path. Emits the PDF 'S' operator.
Example: (pdf-stroke page)
```

### `pdf-text-width`

```
Syntax: (pdf-text-width font size string)
Library: (scm pdf)
Description: Returns the rendered width of string in user-space units
  (points) when set in font at size, using the AFM/TTF glyph widths.
  For core14 fonts, unmappable codepoints are treated as the '?' glyph;
  for embedded TrueType fonts, codepoints without a glyph use GID 0
  (which is .notdef, typically zero width or a blank box).
Example:
  (define helv (pdf-use-font doc 'helvetica))
  (pdf-text-width helv 12 "Hello")
```

### `pdf-transform`

```
Syntax: (pdf-transform page a b c d e f)
Library: (scm pdf)
Description: Concatenates the matrix [a b c d e f] onto the current
  transformation matrix. The PDF CTM is a 3x3 affine matrix whose six
  free entries are passed in column-major order. Emits 'cm'.
Example: (pdf-transform page 1 0 0 1 100 200)   ; translate (100,200)
```

### `pdf-translate`

```
Syntax: (pdf-translate page tx ty)
Library: (scm pdf)
Description: Concatenates a translation by (tx, ty) onto the CTM.
Example: (pdf-translate page 100 200)
```

### `pdf-use-font`

```
Syntax: (pdf-use-font doc font-symbol)
Library: (scm pdf)
Description: Registers one of the 14 standard PDF base fonts on doc
  and returns a font handle suitable for pdf-text-width and
  pdf-draw-text. Repeated calls with the same symbol return the same
  handle.
  font-symbol is one of:
    helvetica  helvetica-bold  helvetica-oblique  helvetica-bold-oblique
    times-roman  times-bold  times-italic  times-bold-italic
    courier  courier-bold  courier-oblique  courier-bold-oblique
    symbol  zapf-dingbats
Example:
  (define helv (pdf-use-font doc 'helvetica))
```

### `pdf-with-state`

```
Syntax: (pdf-with-state page thunk)
Library: (scm pdf)
Description: Calls thunk between a save-state / restore-state pair so
  any transforms, colors, or clip changes made inside do not leak out.
Example:
  (pdf-with-state page
    (lambda ()
      (pdf-translate page 100 100)
      (pdf-set-fill-rgb page 1 0 0)
      (pdf-rect page 0 0 50 50)
      (pdf-fill page)))
```

### `pdf/array`

```
Syntax: (pdf/array list-of-values)
Library: (scm pdf)
Description: Constructs a PDF array from a Scheme list of PDF values.
Example: (pdf/array (list 0 0 595 842))
```

### `pdf/dict`

```
Syntax: (pdf/dict key1 value1 key2 value2 ...)
Library: (scm pdf)
Description: Constructs a PDF dictionary from alternating string keys
  and PDF values. Keys are bare strings (the leading / is added by the
  serializer). Values may be other PDF values, numbers, booleans, the
  symbol 'null, or plain strings (emitted as literal strings).
Example:
  (pdf/dict "Type" (pdf/name "Catalog")
            "Pages" (pdf/ref 2))
```

### `pdf/literal`

```
Syntax: (pdf/literal bytevector)
Library: (scm pdf)
Description: Wraps a bytevector so the PDF serializer splices it
  verbatim into the output stream. Intended for already-formed PDF
  fragments — most users should not need this.
Example: (pdf/literal (string->utf8 "<< /Foo /Bar >>"))
```

### `pdf/name`

```
Syntax: (pdf/name string)
Library: (scm pdf)
Description: Constructs a PDF name object (serialized as /string). Used
  for dictionary keys' values, font names, type tags, etc.
Example: (pdf/name "Catalog")
```

### `pdf/ref`

```
Syntax: (pdf/ref object-id)
Library: (scm pdf)
Description: Constructs an indirect-object reference (serialized as
  "N 0 R"). object-id is the integer id assigned by the writer.
Example: (pdf/ref 3)
```

### `pdf/stream`

```
Syntax: (pdf/stream dict bytevector)
Library: (scm pdf)
Description: Constructs a PDF stream object. dict is a pdf-dict (its
  /Length entry is added automatically if missing). data is the raw
  stream payload as a bytevector — callers are responsible for any
  compression and for setting /Filter accordingly.
Example:
  (pdf/stream (pdf/dict) (string->utf8 "q Q"))
```

