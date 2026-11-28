---
title: (scm image), (scm png), (scm qr), (scm svg raster): images
part: libraries
order: 1024
libraries: (scm image) (scm png) (scm qr) (scm svg raster) (scm svg core)
summary: Pixels as bytevectors, writing PNG files, decoding PNG and JPEG, checking uploads, thumbnails, crops, JPEG output, drawing with (scm raster), QR codes as PNG, SVG and text, rendering SVG to PNG.
---
# (scm image), (scm png), (scm qr), (scm svg raster): images

| library | does |
|---|---|
| `(scm png)` | writes PNG files from raw pixels |
| `(scm image)` | decodes PNG and JPEG, scales, crops, encodes PNG and JPEG |
| `(scm qr)` | makes QR codes |
| `(scm svg raster)` | renders SVG into pixels |

```scheme
(import (scheme base) (scheme write) (srfi 1) (only (srfi 13) string-prefix?)
        (scm fs) (scm png) (scm image) (scm qr) (scm svg raster) (scm raster))

(define dir (mktempdir '(prefix . "img")))
(define (at name) (join-path dir name))
```

## Pixels and PNG files

An image is a bytevector of pixels, row by row from the top. In RGB each
pixel is three bytes:

```scheme
(define (gradient width height)
  (let ((px (make-bytevector (* 3 width height))))
    (do ((y 0 (+ y 1))) ((= y height) px)
      (do ((x 0 (+ x 1))) ((= x width))
        (let ((i (* 3 (+ x (* y width)))))
          (bytevector-u8-set! px i (quotient (* 255 x) (- width 1)))       ; red grows to the right
          (bytevector-u8-set! px (+ i 1) 80)
          (bytevector-u8-set! px (+ i 2) (quotient (* 255 y) (- height 1)))))))) ; blue downwards

(define png (png-encode-rgb 64 32 (gradient 64 32)))
(write-png-file (at "gradient.png") png)
(bytevector-copy png 1 4)                   ;; => #u8(80 78 71)
```

The bytes 2–4 of every PNG file spell "PNG". `png-encode-grayscale` (one
byte per pixel), `png-encode-rgba` (four, with transparency) and
`png-encode` (any of the four colour types) work the same way.

## Reading images

`(scm image)` decodes PNG and JPEG into RGBA images, four bytes per pixel:

```scheme
(define img (image-decode png))
(list (image-width img) (image-height img)) ;; => (64 32)
(bytevector-copy (image-pixels img) 0 4)    ;; => #u8(0 80 0 255)
```

`image-read` reads a file. JPEGs are turned upright by their EXIF
orientation, as browsers show them.

## Checking uploads

`image-info` reads only the header: the format and size, or `#f` for
something that is not a PNG or JPEG. Check uploads with it before
decoding, so a file cannot claim a gigantic size and use up the memory:

```scheme
(image-info png)                            ;; => ((format . png) (width . 64) (height . 32) (orientation . 1))
(image-info (string->utf8 "GIF89a..."))     ;; => #f

(define (acceptable-upload? bytes)
  (let ((info (image-info bytes)))
    (and info
         (<= (* (cdr (assq 'width info)) (cdr (assq 'height info))) 40000000))))

(acceptable-upload? png)                    ;; => #t
(acceptable-upload? (bytevector 1 2 3))     ;; => #f
```

`image-decode` refuses more than 50 million pixels by default anyway
(option `max-pixels`).

## Thumbnails, crops, JPEG

```scheme
(define big (image-decode png))
(define thumb (image-fit big 16 16))
(list (image-width thumb) (image-height thumb)) ;; => (16 8)
(define cropped (image-crop big 16 0 32 32))
(list (image-width cropped) (image-height cropped)) ;; => (32 32)
(define wide (image-resize big 128 32))
(image-width wide)                          ;; => 128

(define jpeg (image->jpeg thumb 80))
(image-info jpeg)                           ;; => ((format . jpeg) (width . 16) (height . 8) (orientation . 1))
(image-info (image->png cropped))            ;; => ((format . png) (width . 32) (height . 32) (orientation . 1))
```

`image-fit` keeps the aspect ratio and never enlarges; `image-resize`
scales to an exact size (box filter when shrinking, bilinear when
enlarging). JPEG is the format for photos, PNG for graphics with sharp
edges or transparency.

## Drawing

`(scm raster)` draws anti-aliased shapes on a canvas; images and canvases
convert into each other, so a photo can get a caption or a watermark:

```scheme
(define c (image->canvas big))
(canvas-fill-path! c (path-rect 0 20 64 12) (rgba 0 0 0 0.6))
(canvas-fill-path! c (path-circle 56 8 5) (rgba 255 255 255))
(define marked (canvas->image c))
(bytevector-copy (image-pixels marked) (* 4 (+ 1 (* 30 64))) (+ 4 (* 4 (+ 1 (* 30 64)))))
;; => #u8(2 32 98 255)
```

The pixel at (1, 30), under the dark band, is now much darker than the
gradient was there.

## QR codes

```scheme
(define code (qr-encode "https://tea.example/order/117"))
(qr-matrix-size code)                       ;; => 29
(qr-matrix-size (qr-encode "https://tea.example/order/117" 'H)) ;; => 33

(define qr-png (qr->png code 6))
(image-info qr-png)                         ;; => ((format . png) (width . 222) (height . 222) (orientation . 1))
(write-png-file (at "order.png") qr-png)
(string-prefix? "<svg" (qr->svg code 4 4))  ;; => #t
```

- The size grows with the data and the error-correction level (`'L`,
  `'M` default, `'Q`, `'H`), which trades size for robustness: `'H` still reads with 30 % of the code damaged, so a
  logo can cover the middle.
- `qr->png` takes the pixels per module (6 here) and the quiet zone in
  modules (4 by default, as scanners need): (29 + 2 × 4) × 6 = 222.
- `qr->svg` gives a vector image for web pages and print;
  `qr->ascii` shows the code in a terminal.

`qr-matrix-ref` reads single modules, for drawing the code yourself.

## SVG to pixels

`(scm svg raster)` renders SVG (text or SXML) to a canvas or a PNG, with
shapes, paths, gradients, text in DejaVu Sans or a TrueType font, CSS
styles and transforms:

```scheme
(define badge "<svg xmlns='http://www.w3.org/2000/svg' width='120' height='40'>
  <rect width='120' height='40' rx='8' fill='#2e7d32'/>
  <text x='60' y='26' font-size='16' text-anchor='middle' fill='white'>Organic</text></svg>")

(define badge-png (svg->png badge '((scale . 2))))
(image-info badge-png)                      ;; => ((format . png) (width . 240) (height . 80) (orientation . 1))
(bytevector-copy (image-pixels (image-decode badge-png)) (* 4 (+ 20 (* 40 240))) (+ 4 (* 4 (+ 20 (* 40 240)))))
;; => #u8(46 125 50 255)

(svg-text->sxml "<svg width='10'><rect height='2'/></svg>")
;; => (svg (@ (width "10")) (rect (@ (height "2"))))
(rm dir 'recursive)
```

`(scale . 2)` renders at twice the size, for high-resolution screens. An
SVG built as SXML with `(scm html builder)`'s tree form can be rendered
directly, without writing it out as text. `(scm svg core)` has the shared
parsing (paths, transforms, CSS) for writing other renderers.

## Where next

- [PDF](scm-pdf.md) for SVG as vectors, [presentations](scm-presentation.md)
  for pictures on slides, `(scm data plot)` for charts, `(scm truetype)`
  for fonts.
- Reference: `(scm image)`, `(scm png)`, `(scm qr)`, `(scm svg raster)`,
  `(scm raster)`.
