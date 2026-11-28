---
title: (scm pdf) and (scm svg pdf): PDF documents
part: libraries
order: 1023
libraries: (scm pdf) (scm svg pdf)
summary: Pages and coordinates, text in the standard fonts, measuring and wrapping text, shapes, colours and transforms, images, links, bookmarks and metadata; drawing SVG as vectors; an invoice and a multi-page report with page numbers.
---
# (scm pdf) and (scm svg pdf): PDF documents

`(scm pdf)` writes PDF files from nothing: pages, text, shapes, images,
links and bookmarks. `(scm svg pdf)` draws SVG on its pages as vectors,
which is how charts get into PDF reports.

```scheme
(import (scheme base) (scheme cxr) (scheme write) (srfi 1)
        (scm fs) (scm png) (scm pdf) (scm svg pdf))

(define dir (mktempdir '(prefix . "pdf")))
(define (at name) (join-path dir name))
```

## Pages and coordinates

```scheme
(define doc (make-pdf))
(define page (pdf-add-page! doc))           ; A4
(list (pdf-page-width page) (pdf-page-height page)) ;; => (595 842)
pdf-page-size-letter                        ;; => (612 . 792)
```

Units are points (1/72 inch). The origin is the **bottom left** corner, so
y grows upwards: the top of an A4 page is y = 842. Other sizes are pairs
or two numbers: `(pdf-add-page! doc 842 595)` is A4 landscape.

## Text

The 14 standard fonts need no font file: `helvetica`, `times-roman`,
`courier`, their bold and italic variants, `symbol` and `zapf-dingbats`.

```scheme
(define helv (pdf-use-font doc 'helvetica))
(define bold (pdf-use-font doc 'helvetica-bold))

(pdf-draw-text page bold 20 72 770 "Teashop")
(pdf-draw-text page helv 11 72 750 "Bahnhofstrasse 1, 8001 Zurich")
```

`pdf-draw-text` puts the *baseline* of the text at (x, y). Measuring comes
before placing, for right-aligned or centred text:

```scheme
(define (round2 x) (/ (round (* 100 x)) 100))
(round2 (pdf-text-width helv 12 "Hello"))   ;; => 27.34
(round2 (pdf-text-width bold 12 "Hello"))   ;; => 29.34

(define (draw-right page font size right-x y text)
  (pdf-draw-text page font size (- right-x (pdf-text-width font size text)) y text))

(draw-right page helv 11 523 770 "Invoice 2025-117")
```

The standard fonts cover Latin-1 (umlauts and accents are fine). For
other scripts, or a corporate font, embed a TrueType font with
`pdf-embed-truetype-font`.

## Wrapping paragraphs

`pdf-flow-text` sets text into a rectangle `(x y width height)`, wrapping
at words. It returns the text that did not fit and where the next line
would go, so text can continue in another column or on the next page:

```scheme
(define story (apply string-append (make-list 20 "Tea is the most consumed drink after water. ")))

(define-values (rest next-y)
  (pdf-flow-text page helv 10 '(72 560 220 120) story 'align 'justify))
(> (string-length rest) 0)                  ;; => #t
(< next-y 560)                              ;; => #t
(define-values (rest2 next-y2) (pdf-flow-text page helv 10 '(303 560 220 120) rest 'align 'justify))
(string-length rest2)                       ;; => 0
```

The first column overflowed, the second took the rest. Alignment is
`'left`, `'right`, `'center` or `'justify`; `'leading` sets the line
spacing.

## Shapes and colours

Paths are built with `pdf-move-to`, `pdf-line-to`, `pdf-curve-to` and
`pdf-rect`, then painted with `pdf-stroke`, `pdf-fill` or both.
`pdf-with-state` keeps colours and transforms from leaking out:

```scheme
(pdf-with-state page
  (lambda ()
    (pdf-set-fill-rgb page 0.18 0.49 0.2)
    (pdf-rect page 72 700 451 3)
    (pdf-fill page)))

(pdf-with-state page
  (lambda ()
    (pdf-translate page 470 600)
    (pdf-rotate page 30)
    (pdf-set-stroke-rgb page 0.8 0.1 0.1)
    (pdf-set-line-width page 2)
    (pdf-rect page -40 -12 80 24)
    (pdf-stroke page)
    (pdf-draw-text page bold 12 -22 -4 "PAID")))
```

Dashes, caps, joins, CMYK and grey colours, opacity and clipping are
there as well (`pdf-set-dash`, `pdf-set-fill-cmyk`, `pdf-set-opacity`,
`pdf-clip`).

## Images, links, bookmarks, metadata

```scheme
(define logo (pdf-embed-png doc (png-encode-rgb 2 2 (bytevector 46 125 50  255 255 255  255 255 255  46 125 50))))
(pdf-draw-image page logo 480 760 40 40)

(pdf-draw-text page helv 10 72 100 "Order online: https://tea.example")
(pdf-add-link page '(72 95 260 110) "https://tea.example")
(pdf-add-outline! doc page "Invoice")
(pdf-set-metadata! doc 'title "Invoice 2025-117" 'author "Teashop")

(pdf-save doc (at "invoice.pdf"))
(utf8->string (bytevector-copy (pdf->bytevector doc) 0 8)) ;; => "%PDF-1.4"
```

`pdf-embed-jpeg` takes JPEG files as they are, without re-encoding.
`pdf->bytevector` returns the document as bytes, for an HTTP response.

## Example: an invoice table

A table is text in columns plus a few lines. Keep the layout in one
place, a list of columns with their width and alignment:

```scheme
(define columns '(("Item" 230 left) ("Kg" 60 right) ("Price" 80 right) ("Total" 80 right)))

(define (money x) (let ((cents (exact (round (* 100 x)))))
                    (string-append (number->string (quotient cents 100)) "."
                                   (let ((c (number->string (remainder cents 100))))
                                     (if (< (string-length c) 2) (string-append "0" c) c)))))

(define (draw-row page font y cells)
  (let loop ((x 72) (cols columns) (cells cells))
    (unless (null? cols)
      (let ((w (cadar cols)) (align (caddar cols)) (text (car cells)))
        (if (eq? align 'right)
            (draw-right page font 10 (+ x w -4) y text)
            (pdf-draw-text page font 10 (+ x 4) y text))
        (loop (+ x w) (cdr cols) (cdr cells))))))

(define (invoice lines)
  (let* ((doc (make-pdf)) (page (pdf-add-page! doc))
         (helv (pdf-use-font doc 'helvetica)) (bold (pdf-use-font doc 'helvetica-bold)))
    (pdf-draw-text page bold 16 72 770 "Invoice")
    (draw-row page bold 700 (map car columns))
    (let loop ((y 682) (lines lines) (sum 0))
      (if (null? lines)
          (begin
            (pdf-set-line-width page 0.5)
            (pdf-move-to page 72 (+ y 12)) (pdf-line-to page 522 (+ y 12)) (pdf-stroke page)
            (draw-row page bold y (list "Total" "" "" (money sum)))
            (values doc sum))
          (let* ((l (car lines)) (total (* (cadr l) (caddr l))))
            (draw-row page helv y (list (car l) (number->string (cadr l)) (money (caddr l)) (money total)))
            (loop (- y 18) (cdr lines) (+ sum total)))))))

(define-values (inv sum) (invoice '(("Sencha" 2 24.5) ("Matcha" 0.5 96) ("Assam" 1 18.4))))
(money sum)                                 ;; => "115.40"
(pdf-save inv (at "invoice2.pdf"))
(file-exists? (at "invoice2.pdf"))          ;; => #t
```

## Example: page numbers

"Page 3 of 7" needs the total, so draw the footers after all pages exist:

```scheme
(define report (make-pdf))
(define rfont (pdf-use-font report 'times-roman))
(define pages
  (map (lambda (n)
         (let ((p (pdf-add-page! report)))
           (pdf-draw-text p rfont 14 72 770 (string-append "Chapter " (number->string n)))
           p))
       (iota 3 1)))
(for-each (lambda (p n)
            (let ((label (string-append "Page " (number->string n) " of " (number->string (length pages)))))
              (pdf-draw-text p rfont 9 (- 297 (/ (pdf-text-width rfont 9 label) 2)) 30 label)))
          pages (iota (length pages) 1))
(pdf-page-count report)                     ;; => 3
```

## SVG as vectors

`(scm svg pdf)` draws SVG on a page: paths stay paths and text stays
text, so a chart prints sharp and its labels can be searched:

```scheme
(define chart "<svg xmlns='http://www.w3.org/2000/svg' width='300' height='120'>
  <rect x='10' y='60' width='60' height='50' fill='#2e7d32'/>
  <rect x='90' y='20' width='60' height='90' fill='#66bb6a'/>
  <text x='10' y='12' font-size='12'>Kg sold</text></svg>")

(call-with-values (lambda () (svg-size chart)) list) ;; => (300.0 120.0)
(call-with-values
  (lambda () (svg->pdf-page! report (car pages) chart 72 740 '((width . 450))))
  list)                                     ;; => (450.0 180.0)
(pdf-save report (at "report.pdf"))

(define single (svg->pdf chart '((margin . 10))))
(utf8->string (bytevector-copy single 0 5)) ;; => "%PDF-"
(rm dir 'recursive)
```

`svg->pdf-page!` puts the drawing's top-left corner at (x, y) and scales it
to the given width; `svg->pdf` makes a one-page PDF the size of the
drawing. `(scm data plot)` and `(scm data report)` use these for charts in
PDF reports.

## Where next

- [Images, QR codes and SVG](scm-images.md), [Word documents](scm-word.md),
  `(scm truetype)` for fonts, `(scm data report)` for whole reports.
- Reference: `(scm pdf)`, `(scm svg pdf)`.
