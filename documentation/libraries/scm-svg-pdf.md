# `(scm svg pdf)`

SVG drawn on PDF pages as vectors, with embedded fonts

## Overview

Draws SVG on pages of `(scm pdf)` as vectors: paths stay paths (fills, strokes
with joins, caps and dashes, opacity, even-odd fills) and text stays text, set
in an embedded font (DejaVu Sans by default, or fonts of `(scm truetype)`), so
it scales, prints sharp and can be searched and copied. The SVG subset is that
of `(scm svg raster)`, without patterns. Each font is embedded once per
document (`svg-pdf-font`), also when a page adds its own text in it.

## Common uses

```scheme
(import (scm pdf) (scm svg pdf))

;; a one-page PDF the size of the drawing
(svg->pdf chart-sxml '((width . 400) (margin . 10)))

;; on a page of a larger document: top-left corner at (50, 790), 495 points wide
(svg->pdf-page! doc page chart-sxml 50 790 '((width . 495)))
```

`(scm data plot)` uses it for `plot->pdf`, `(scm data report)` for figures in
`report->pdf`.


## Exports

### `svg->pdf`

```
Syntax: (svg->pdf svg [options])
Library: (scm svg pdf)
Description: A one-page PDF (bytevector) of svg, the page the size of
  the drawing (one SVG unit = one point, or scaled to (width . w) or
  (height . h)) plus (margin . m) points on each side, 0 by default.
  options as for svg->pdf-page!, and (title . s) for the document's
  metadata.
Example:
  (pdf-save-bytes (svg->pdf chart '((width . 400) (margin . 10))))
```

### `svg->pdf-page!`

```
Syntax: (svg->pdf-page! doc page svg x y [options])
Library: (scm svg pdf)
Description: Draws svg (SVG text or an SXML tree) on page, a page of doc,
  with its top-left corner at (x, y) in PDF points (y counts from the
  bottom of the page, as everywhere in (scm pdf)). One SVG unit is one
  point unless options give (width . w) or (height . h) in points, which
  scale the drawing (keeping its aspect ratio). Returns the drawn width
  and height as two values. options is an alist: width, height, and
  (fonts . ((normal . font) (bold . font))) fonts of (scm truetype),
  DejaVu Sans by default.
Example:
  (svg->pdf-page! doc page chart 50 790 '((width . 495)))
```

### `svg-pdf-font`

```
Syntax: (svg-pdf-font doc font)
Library: (scm svg pdf)
Description: The PDF font of doc for font, a font of (scm truetype),
  embedded on first use and shared with the SVG drawn on doc, so a page
  that adds its own text in the same font embeds it only once.
Example:
  (pdf-draw-text page (svg-pdf-font doc dejavu-sans) 10 50 700 "Hello")
```

### `svg-size`

```
Syntax: (svg-size svg)
Library: (scm svg pdf)
Description: The width and height of svg (SVG text or SXML) in its own
  units, as two values: the root's width and height, or its viewBox's
  size, or 300 by 150.
Example:
  (svg-size "<svg width='20' height='10'/>") => 20 10
```

