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
