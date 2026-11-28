---
title: "(scm truetype), (scm fonts) and (scm text layout): fonts and text"
part: libraries
order: 1043
libraries: (scm truetype) (scm fonts) (scm fonts dejavu) (scm fonts inter) (scm fonts roboto-slab) (scm text layout) (scm raster)
summary: The built-in fonts, measuring text with kerning, glyphs and their outlines, finding installed font families by weight and style, reading TrueType files, subsetting a font for embedding, drawing text into pixels, breaking styled paragraphs into lines (left, centred, justified, hard breaks) and drawing them.
---
# (scm truetype), (scm fonts) and (scm text layout): fonts and text

Charts, PDF reports and images need text that is measured and drawn
exactly. Three layers do this:

| library | does |
|---|---|
| `(scm truetype)` | reads TrueType fonts, measures text, gives glyph outlines |
| `(scm fonts)` | finds installed font families by weight and style |
| `(scm text layout)` | breaks paragraphs of styled text into lines |

Three families are compiled into dabscm, so there is always a font
without any files: `(scm fonts dejavu)` (`dejavu-sans`,
`dejavu-sans-bold`), `(scm fonts inter)` (`inter-regular`,
`inter-black`) and `(scm fonts roboto-slab)` (`roboto-slab-regular`,
`roboto-slab-bold`). They cover Latin, Greek and Cyrillic.

```scheme
(import (scheme base) (scheme write) (scm truetype) (scm fonts) (scm fonts inter)
        (scm text layout) (scm raster) (scm image))

(define (round2 x) (/ (round (* 100 x)) 100))
```

## Measuring text

```scheme
(font? inter-regular)                       ;; => #t
(round2 (font-text-width inter-regular 16 "Teashop")) ;; => 64.84
(round2 (font-text-width inter-black 16 "Teashop"))   ;; => 69.27
```

The width is for a size in pixels (or points, or any unit) per em, the
font's design square. Kerning is included: pairs like "AV" are moved
closer than their glyphs' widths say:

```scheme
(font-units-per-em inter-regular)           ;; => 2048
(font-kerning inter-regular #\A #\V)        ;; => -140
(car (font-glyph inter-regular #\A))        ;; => 1413
```

A glyph is its advance width and its contours, in font units: at 16
pixels per em, Inter's "A" advances 1413 / 2048 × 16 ≈ 11 pixels. The
ascent and descent tell how far the font reaches above and below the
baseline:

```scheme
(list (font-ascent inter-regular) (font-descent inter-regular)) ;; => (1984 -494)
```

Measuring is what right-aligned table columns, centred titles and
"does this label fit in the bar?" need.

## Installed fonts

`(scm fonts)` looks for TrueType files along a search path (the user's
`~/.local/share/dabscm/fonts`, then system directories) and picks a
face by family, weight and style:

```scheme no-test
(font-families)               ; => ("IBM Plex Sans" "Inter" "JetBrains Mono" "Roboto" ...)
(font-faces "JetBrains Mono") ; => ((400 #f) (700 #f) (400 #t) (700 #t))
(define code-font (find-font "JetBrains Mono" 'bold 'italic))
(font-license "JetBrains Mono")
```

`find-font` returns the nearest face, or `#f` when the family is
missing, so a program can fall back to a built-in font:

```scheme
(define body-font (or (find-font "No Such Family") inter-regular))
(eq? body-font inter-regular)               ;; => #t
```

`read-truetype` reads any `.ttf` file given as a bytevector, with
OpenType features such as tabular figures (`'((features "tnum"))`);
`truetype-info` reads only its names.

## Subsetting for embedding

`font->truetype` writes a font as a TrueType file, optionally with only
the characters needed. That is how a PDF embeds a few kilobytes instead
of a whole font:

```scheme
(define subset (font->truetype inter-regular "Inter" "Regular" "Teashop"))
(truetype-info subset)                      ;; => ((family . "Inter") (style . "Regular") (weight . 400) (italic . #f))
(define back (read-truetype subset))
(round2 (font-text-width back 16 "Teashop")) ;; => 65.94
```

The subset measures a little wider: it has no kerning table, because a
PDF positions the glyphs itself with the kerning of the original font.
`pdf-embed-truetype-font` in `(scm pdf)` takes such a file.

## Drawing text into pixels

`font-text-path` turns text into a path for `(scm raster)`; filled, it
gives anti-aliased text in an image:

```scheme
(define c (make-canvas 200 40 (rgba 255 255 255)))
(canvas-fill-path! c (font-text-path inter-regular 24 10 30 "Teashop") (rgba 30 60 40))
(image-info (canvas->png c))                ;; => ((format . png) (width . 200) (height . 40) (orientation . 1))
```

The text starts at x = 10 on the baseline y = 30; canvas y points down.
This is how `(scm svg raster)` renders the text of SVG charts.

## Breaking paragraphs into lines

`(scm text layout)` does the step between measuring and drawing: it
breaks a paragraph into lines that fit a width. A paragraph is a list
of *runs*, pieces of text in one style, each with a procedure that
measures it:

```scheme
(define (run text size . data)
  (make-text-run text (lambda (s) (font-text-width inter-regular size s))
                 size (* size 0.97) (* size 0.24) (if (pair? data) (car data) #f)))

(define lines
  (layout-paragraph
   (list (run "Tea is the most consumed drink in the world after water, and it comes in many kinds." 12))
   200))

(map (lambda (l) (apply string-append (map item-text (line-items l)))) lines)
;; => ("Tea is the most consumed drink in" "the world after water, and it comes" "in many kinds.")
(map (lambda (l) (round2 (line-width l))) lines) ;; => (193.21 196.21 80.84)
(round2 (layout-height lines))              ;; => 43.2
```

Each line holds *items*, pieces of text with their position from the
start of the line, and has a height and a baseline. The line height is
1.2 times the font size by default, as in CSS (`(line-height . 1.5)`
changes it). `(align . justify)` stretches the spaces, so every line but
the last fills the width; its items are then single words, placed
apart:

```scheme
(map (lambda (l) (map item-text (line-items l)))
     (layout-paragraph (list (run "Tea is the most consumed drink in the world after water." 12)) 200
                       '((align . justify))))
;; => (("Tea" "is" "the" "most" "consumed" "drink" "in") ("the world after water."))
```

Runs of different styles share lines. The data given to a run (here the
symbol `bold`) comes back with its items, to choose the font or colour
when drawing; `"\n"` breaks a line:

```scheme
(define (bold text size)
  (make-text-run text (lambda (s) (font-text-width inter-black size s)) size (* size 0.97) (* size 0.24) 'bold))

(define mixed (layout-paragraph (list (run "Order " 12) (bold "now" 12) (run " and save.\nThanks!" 12)) 300))
(map (lambda (l) (map (lambda (i) (list (item-text i) (text-run-data (item-run i)) (round2 (item-x i))))
                      (line-items l)))
     mixed)
;; => ((("Order " #f 0) ("now" bold 35.58) ("and save." #f 64.5)) (("Thanks!" #f 0)))
(map line-hard-break? mixed)                ;; => (#t #f)
```

## Drawing a laid-out paragraph

Drawing is a loop over the lines and their items, here into a canvas
(the same loop with `pdf-draw-text` fills a PDF page):

```scheme
(define (draw-paragraph! canvas lines left top)
  (let loop ((lines lines) (y top))
    (unless (null? lines)
      (let ((l (car lines)))
        (for-each (lambda (item)
                    (let ((font (if (eq? (text-run-data (item-run item)) 'bold) inter-black inter-regular)))
                      (canvas-fill-path! canvas
                                         (font-text-path font (text-run-size (item-run item))
                                                         (+ left (item-x item)) (+ y (line-baseline l))
                                                         (item-text item))
                                         (rgba 0 0 0))))
                  (line-items l))
        (loop (cdr lines) (+ y (line-height l)))))))

(define card (make-canvas 320 60 (rgba 255 255 255)))
(draw-paragraph! card mixed 10 10)
(canvas-width card)                         ;; => 320
```

The layout follows the rules of a browser showing `white-space:
pre-wrap` text, including CSS line heights, so a PDF can reproduce what
a web page shows.

## Where next

- [PDF](scm-pdf.md) for embedding fonts in documents,
  [images](scm-images.md) for `(scm raster)` and SVG rendering,
  [charts](scm-data-plot.md) and [reports](scm-data-report.md), which
  use all of this.
- Reference: `(scm truetype)`, `(scm fonts)`, `(scm text layout)`,
  `(scm raster)`.
