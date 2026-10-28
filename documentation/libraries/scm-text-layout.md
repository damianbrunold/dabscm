# `(scm text layout)`

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


## Exports

### `item-run`

*(no documentation)*

### `item-text`

*(no documentation)*

### `item-width`

*(no documentation)*

### `item-x`

*(no documentation)*

### `layout-height`

```
Syntax: (layout-height lines)
Library: (scm text layout)
Description: The total height of lines from layout-paragraph.
```

### `layout-paragraph`

```
Syntax: (layout-paragraph runs width [options])
Library: (scm text layout)
Description: Breaks the runs (see make-text-run) into lines no wider
  than width and returns the lines, each with its items (pieces of text
  with their x offset from the line start, width and run), natural
  width, height, baseline (distance from the line's top) and whether it
  ended with "\n". options is an alist: (align . left | center | right
  | justify), (line-height . factor) (default 1.2, times each run's
  size), (strut . run) a run for the paragraph's own font, which sets
  the minimum line height (as in CSS). Justified lines (all but the
  last and those ending with "\n") stretch their spaces; their items
  are single words. An empty paragraph gives one empty line.
Example:
  (for-each (lambda (line) ...) (layout-paragraph runs 400 '((align . justify))))
```

### `line-baseline`

*(no documentation)*

### `line-hard-break?`

*(no documentation)*

### `line-height`

*(no documentation)*

### `line-items`

*(no documentation)*

### `line-width`

*(no documentation)*

### `make-text-run`

```
Syntax: (make-text-run text measure size ascent descent [data])
Library: (scm text layout)
Description: A run of text in one style. (measure string) returns the
  width of string in this style; size is the font size, ascent and
  descent the font's extent above and below the baseline (positive), all
  in the same unit as the widths. data is anything the caller wants back
  with the run's pieces (its colour, font, link ...).
Example:
  (make-text-run "Hallo" (lambda (s) (pdf-text-width f 12 s)) 12 11.6 2.9 'black)
```

### `text-run-data`

*(no documentation)*

### `text-run-size`

*(no documentation)*

### `text-run-text`

*(no documentation)*

### `text-run?`

*(no documentation)*

