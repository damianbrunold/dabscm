# `(scm ooxml presentation)`

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


## Exports

### `inches->emu`

*(no documentation)*

### `make-presentation`

```
Syntax: (make-presentation [width-emu height-emu])
Library: (scm ooxml presentation)
Description: A new, empty presentation; slides are 16:9 (12192000 x
  6858000 EMU, 13.33 x 7.5 inches) unless a size is given.
Example:
  (define p (make-presentation))
```

### `points->emu`

*(no documentation)*

### `presentation->bytevector`

```
Syntax: (presentation->bytevector pres)
Library: (scm ooxml presentation)
Description: pres as the bytes of a .pptx file.
```

### `presentation-add-slide!`

```
Syntax: (presentation-add-slide! pres)
Library: (scm ooxml presentation)
Description: Appends a blank slide and returns it.
```

### `presentation-save`

```
Syntax: (presentation-save pres path)
Library: (scm ooxml presentation)
Description: Writes pres as a .pptx file at path.
```

### `presentation-set-title!`

```
Syntax: (presentation-set-title! pres title)
Library: (scm ooxml presentation)
Description: Sets the document title (file properties).
```

### `slide-add-line!`

```
Syntax: (slide-add-line! slide x y w h [options])
Library: (scm ooxml presentation)
Description: Adds a straight line from the top-left to the bottom-right
  corner of the box (or, with (flip . #t), from the bottom-left to the
  top-right). options: (color . color), (width . emu), (name . string),
  (build . (order effect)).
```

### `slide-add-picture!`

```
Syntax: (slide-add-picture! slide source mime x y w h [options])
Library: (scm ooxml presentation)
Description: Adds a picture: source is a bytevector or the path of a
  file, mime image/png, image/jpeg or image/gif. options: (crop . (left
  top right bottom)) the fractions of the image cut off at each side,
  (alpha . 0..1), (rotation . degrees), (description . alt-text),
  (key . string) to store the same image once (default: the path, or
  the bytevector itself), (name . string), (build . (order effect)).
```

### `slide-add-shape!`

```
Syntax: (slide-add-shape! slide kind x y w h [options])
Library: (scm ooxml presentation)
Description: Adds a shape: kind is rect, rounded, ellipse, triangle,
  arrow (pointing right), chevron, or text (a rectangle without fill or
  outline, for text boxes). options is an alist: (fill . color),
  (fill-alpha . 0..1), (line . color), (line-width . emu), (rotation .
  degrees), (text . paragraphs), (anchor . top | middle | bottom),
  (insets . (left top right bottom)) the space in EMU between the edge
  and the text (default none), (name . string), (build . (order effect))
  with effect appear, fade, fly-left, fly-right, fly-up (from below),
  fly-down (from above).
Example:
  (slide-add-shape! s 'rounded 914400 914400 3657600 1828800
    '((fill . "0070B4")
      (text . (((align . center) (runs . (((text . "Hallo") (size . 28) (color . "FFFFFF")))))))
      (anchor . middle)))
```

### `slide-add-table!`

```
Syntax: (slide-add-table! slide x y w h rows [options])
Library: (scm ooxml presentation)
Description: Adds a table. rows is a list of rows, a row a list of cells
  (every row as long as the first), a cell an alist: (text . paragraphs),
  (fill . color), (anchor . top | middle | bottom). Columns share the
  width equally unless options has (column-widths . (emu ...)); rows are
  h / rows high (PowerPoint makes a row higher when its text needs it)
  unless (row-heights . (emu ...)). Other options: (margins . (left top
  right bottom)) in EMU (default 91440 45720 91440 45720), (header . #t)
  (the first row is a header row), (name . string), (build . (order
  effect)). Cells have no borders.
Example:
  (slide-add-table! s 914400 914400 7315200 1828800
    (list (list '((text . (((runs . (((text . "Name") (bold . #t))))))) (fill . "0070B4"))
                '((text . (((runs . (((text . "Wert") (bold . #t))))))) (fill . "0070B4")))
          (list '((text . (((runs . (((text . "a")))))))) '((text . (((runs . (((text . "1"))))))))))
    '((header . #t)))
```

### `slide-add-video!`

```
Syntax: (slide-add-video! slide source poster poster-mime x y w h [options])
Library: (scm ooxml presentation)
Description: Adds an MP4 video (source: bytevector or file path) shown
  as poster (an image, as for slide-add-picture!) until it plays; in
  PowerPoint a click on it plays it. options as for slide-add-picture!
  (crop and alpha apply to the poster), (poster-key . string) to store the
  poster once.
```

### `slide-set-background!`

```
Syntax: (slide-set-background! slide color)
Library: (scm ooxml presentation)
Description: Fills the slide's background with color ("RRGGBB").
```

### `slide-set-notes!`

```
Syntax: (slide-set-notes! slide paragraphs)
Library: (scm ooxml presentation)
Description: The speaker notes of the slide (paragraphs as for text).
```

### `slide-set-transition!`

```
Syntax: (slide-set-transition! slide type [milliseconds])
Library: (scm ooxml presentation)
Description: The transition into the slide: fade, push-left, push-up,
  wipe-left, zoom or none; the speed is chosen from milliseconds (fast
  below 400, slow from 800, else medium).
```

