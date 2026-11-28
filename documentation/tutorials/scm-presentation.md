---
title: (scm ooxml presentation): PowerPoint slides
part: libraries
order: 1022
libraries: (scm ooxml presentation)
summary: Slides with positioned shapes, formatted text, bullets, tables, pictures and lines; units; backgrounds, transitions, build animations and speaker notes; a deck generated from data.
---
# (scm ooxml presentation): PowerPoint slides

`(scm ooxml presentation)` writes `.pptx` files. A slide is a canvas:
shapes, text boxes, tables and pictures are placed at absolute positions,
which suits generated decks (reports, dashboards, exports).

```scheme
(import (scheme base) (scheme cxr) (scheme write) (srfi 1) (only (srfi 13) string-prefix?)
        (scm fs) (scm zip) (scm png) (scm ooxml presentation))

(define dir (mktempdir '(prefix . "pptx")))
(define (at name) (join-path dir name))
```

## Units

Positions and sizes are in EMU, English Metric Units: 914400 per inch,
12700 per point. A default slide is 16:9, 13.33 × 7.5 inches:

```scheme
(inches->emu 1)                             ;; => 914400
(points->emu 12)                            ;; => 152400
(define (in x) (inches->emu x))
```

Colours are `"RRGGBB"` strings, font sizes points.

## Text

Text is a list of paragraphs; a paragraph has *runs* and options such as
alignment and bullets:

```scheme
(define (run text . opts) `((text . ,text) ,@opts))
(define (para runs . opts) `((runs . ,runs) ,@opts))

(define deck (make-presentation))
(presentation-set-title! deck "Teashop 2025")

(define title-slide (presentation-add-slide! deck))
(slide-set-background! title-slide "1F3A2E")
(slide-add-shape! title-slide 'text (in 1) (in 2.5) (in 11.3) (in 1.5)
  `((text . (,(para (list (run "Teashop 2025" '(size . 54) '(bold . #t) '(color . "FFFFFF")))
                    '(align . center))
             ,(para (list (run "Year in review" '(size . 28) '(color . "C8E6C9")))
                    '(align . center))))
    (anchor . middle)))
```

Bulleted lists are paragraphs with a bullet character and a hanging
indent:

```scheme
(define (bullet text)
  (para (list (run text '(size . 24))) '(bullet . "•") '(margin-left . 342900) '(indent . -342900)))

(define facts (presentation-add-slide! deck))
(slide-add-shape! facts 'text (in 0.8) (in 0.4) (in 11) (in 1)
  `((text . (,(para (list (run "Highlights" '(size . 40) '(bold . #t))))))))
(slide-add-shape! facts 'text (in 0.8) (in 1.6) (in 6) (in 4)
  `((text . ,(map bullet '("18 % more visitors" "Matcha sold out twice" "New shop in Basel")))))
```

## Shapes, lines and builds

Shapes are `rect`, `rounded`, `ellipse`, `triangle`, `arrow`, `chevron` and
`text`. With `(build . (order effect))` they appear one after the other
during the presentation:

```scheme
(for-each (lambda (label i)
            (slide-add-shape! facts 'chevron (in (+ 7.2 (* i 1.9))) (in 2) (in 1.8) (in 1)
              `((fill . "2E7D32")
                (text . (,(para (list (run label '(size . 16) '(color . "FFFFFF"))) '(align . center))))
                (anchor . middle)
                (build . (,(+ i 1) fade)))))
          '("Buy" "Brew" "Enjoy") '(0 1 2))
(slide-add-line! facts (in 0.8) (in 1.4) (in 11.7) 0 '((color . "2E7D32") (width . 25400)))
(slide-set-transition! facts 'push-left 600)
(slide-set-notes! facts (list (para (list (run "Mention the Basel opening date.")))))
```

Speaker notes are shown in the presenter view, not on the slide.

## Tables and pictures

```scheme
(define (cell text . opts)
  `((text . (,(para (list (run text '(size . 18))) '(align . center)))) (anchor . middle) ,@opts))

(define numbers (presentation-add-slide! deck))
(slide-add-table! numbers (in 0.8) (in 1) (in 6) (in 2)
  (list (list (cell "Tea" '(fill . "C8E6C9")) (cell "Kg" '(fill . "C8E6C9")))
        (list (cell "Sencha") (cell "1 240"))
        (list (cell "Matcha") (cell "310")))
  '((header . #t)))

(define pixel (png-encode-rgb 2 2 (bytevector 46 125 50  200 230 201  200 230 201  46 125 50)))
(slide-add-picture! numbers pixel "image/png" (in 7.5) (in 1) (in 4) (in 4)
                    '((description . "Sales chart")))
```

Pictures are bytevectors or file names (PNG, JPEG or GIF). The
description is the alternative text for screen readers. A chart from
`(scm data plot)` or an SVG rendered with `(scm svg raster)` fits here.

## Saving

```scheme
(presentation-save deck (at "review.pptx"))
(define z (open-input-zip-file (at "review.pptx")))
(filter (lambda (n) (string-prefix? "ppt/slides/slide" n)) (zip-entry-names z))
;; => ("ppt/slides/slide1.xml" "ppt/slides/slide2.xml" "ppt/slides/slide3.xml")
(close-input-zip z)
```

A `.pptx` file is a ZIP archive with one XML part per slide.
`presentation->bytevector` returns the bytes instead of writing a file.

## Example: one slide per record

```scheme
(define shops '(("Zurich" 5400 "+12 %") ("Bern" 3100 "+4 %") ("Basel" 900 "new")))

(define report (make-presentation))
(for-each
 (lambda (shop)
   (let ((s (presentation-add-slide! report)))
     (slide-add-shape! s 'text (in 0.8) (in 0.5) (in 11) (in 1)
       `((text . (,(para (list (run (car shop) '(size . 44) '(bold . #t))))))))
     (slide-add-shape! s 'rounded (in 0.8) (in 2) (in 5) (in 3)
       `((fill . "2E7D32")
         (text . (,(para (list (run (number->string (cadr shop)) '(size . 60) '(color . "FFFFFF")))
                         '(align . center))
                  ,(para (list (run "visitors" '(size . 20) '(color . "FFFFFF"))) '(align . center))))
         (anchor . middle)))
     (slide-add-shape! s 'text (in 6.5) (in 2) (in 5) (in 3)
       `((text . (,(para (list (run (caddr shop) '(size . 60) '(color . "2E7D32")))
                         '(align . center))))
         (anchor . middle)))))
 shops)
(presentation-save report (at "shops.pptx"))
(file-exists? (at "shops.pptx"))           ;; => #t

(rm dir 'recursive)
```

## Where next

- [Word documents](scm-word.md), [images](scm-images.md) for pictures,
  `(scm data plot)` for charts.
- Reference: `(scm ooxml presentation)`.
