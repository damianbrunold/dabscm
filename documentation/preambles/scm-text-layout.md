## Overview

`(scm text layout)` breaks paragraphs of styled text into lines: the part
of text rendering between measuring glyphs and drawing them. A paragraph is
a list of runs (text in one style, with a procedure that measures it and
the font's size, ascent and descent); `layout-paragraph` returns lines with
positioned pieces, the way a browser lays out `white-space: pre-wrap` text,
including CSS line heights, so a PDF can match what a web page showed.

## Common uses

```scheme
(import (scm pdf) (scm truetype) (scm fonts inter) (scm text layout))

(define doc (make-pdf))
(define page (pdf-add-page! doc))
(define inter (pdf-embed-truetype-font doc (font->truetype inter-regular "Inter") "Inter"))

(define (run text size)
  (make-text-run text (lambda (s) (pdf-text-width inter size s)) size
                 (* size 0.97) (* size 0.24)))

(let loop ((lines (layout-paragraph (list (run "Ein langer Absatz ..." 12)) 300
                                    '((align . justify))))
           (top 780))
  (unless (null? lines)
    (for-each (lambda (item)
                (pdf-draw-text page inter (text-run-size (item-run item))
                               (+ 72 (item-x item))
                               (- top (line-baseline (car lines)))
                               (item-text item)))
              (line-items (car lines)))
    (loop (cdr lines) (- top (line-height (car lines))))))
```
