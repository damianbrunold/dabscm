## Overview

`(scm ooxml presentation)` writes PowerPoint files (.pptx). Slides hold
absolutely positioned shapes (preset geometries, optionally with formatted
text), lines, tables, pictures and MP4 videos, and carry a background colour, a
transition, build animations (appear, fade, fly in) and speaker notes. The
package has one master and one blank layout, so everything a slide shows is
on the slide itself: what an export from another program needs. Images and
videos can be file paths; they are copied into the package in pieces.

Positions and sizes are in EMU (914400 per inch; `points->emu`,
`inches->emu`), font sizes in points, angles in degrees, colours "RRGGBB".
A text run with `(field . slide-number)` or `(field . date)` becomes a
PowerPoint field that PowerPoint keeps up to date (slide numbers in footers).

## Common uses

```scheme
(import (scm ooxml presentation))

(define p (make-presentation))                      ; 16:9
(define s (presentation-add-slide! p))
(slide-set-background! s "FFFFFF")
(slide-add-shape! s 'text (inches->emu 1) (inches->emu 0.5) (inches->emu 11) (inches->emu 1.2)
  '((text . (((runs . (((text . "Jahresbericht") (size . 40) (bold . #t)))))
             ((bullet . "•") (margin-left . 342900) (indent . -342900)
              (runs . (((text . "Mehr Besuche") (size . 24)))))))
    (anchor . bottom)))
(slide-add-shape! s 'rounded (inches->emu 1) (inches->emu 3) (inches->emu 3) (inches->emu 2)
  '((fill . "0070B4") (build . (1 fade))))
(define (cell str) `((text . (((runs . (((text . ,str) (size . 18))))))) (anchor . middle)))
(slide-add-table! s (inches->emu 5) (inches->emu 3) (inches->emu 6) (inches->emu 2)
  (list (list (cell "Jahr") (cell "Besuche"))
        (list (cell "2025") (cell "12 400")))
  '((header . #t)))
(slide-add-picture! s "chart.png" "image/png" (inches->emu 5) (inches->emu 3)
                    (inches->emu 4) (inches->emu 3) '((description . "Besuche pro Jahr")))
(slide-set-notes! s '(((runs . (((text . "Zahlen aus dem Bericht")))))))
(presentation-save p "bericht.pptx")
```
