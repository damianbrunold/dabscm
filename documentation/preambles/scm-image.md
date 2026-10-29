## Overview

`(scm image)` decodes PNG and JPEG files, scales, crops and turns images, and
encodes them as PNG or JPEG. An image is width × height pixels of straight
RGBA (8 bits per channel, rows top to bottom), the pixel format of
`(scm raster)` canvases, so you can decode a photo, draw on it and encode it
again.

- **PNG**: every colour type and bit depth (1 to 16 bits), palettes,
  transparency (tRNS), Adam7 interlacing.
- **JPEG**: baseline and progressive Huffman-coded frames, any sampling
  factors, restart intervals; grayscale, YCbCr, RGB, CMYK and YCCK (Adobe).
  Subsampled colour is interpolated as libjpeg does, so pixels come out
  within a few levels of libjpeg's. Arithmetic-coded, lossless and 12-bit
  JPEGs are refused.
- **EXIF orientation**: JPEGs are turned upright when decoded, as browsers
  show them (`(orient . #f)` keeps them as stored).
- **Limits**: `image-decode` refuses images of more than 50 million pixels
  (option `max-pixels`) before decoding them, so an upload cannot claim a
  gigantic size and exhaust memory. `image-info` reads only the headers.

Decoding, resizing, orientation and JPEG encoding run as native code (the
same algorithms in the Java and .NET builds, which give identical pixels): a
12-megapixel JPEG decodes in about a second.

## Common uses

```scheme
(import (scm image))

;; Validate an upload (bytes: a bytevector) without decoding it, then make
;; a thumbnail.
(let ((info (image-info bytes)))
  (unless (and info (<= (* (cdr (assq 'width info)) (cdr (assq 'height info))) 40000000))
    (error "not a usable image")))
(define photo (image-decode bytes))                  ; upright by EXIF
(define thumb (image-fit photo 400 400))             ; at most 400 x 400
(define jpeg (image->jpeg thumb 80))                 ; bytevector

;; Exact sizes, crops, other filters.
(image-resize photo 1920 1080 'bilinear)
(image-crop photo 100 100 800 600)

;; Draw on a photo with (scm raster).
(import (scm raster))
(define c (image->canvas photo))
(canvas-fill-path! c (path-rect 0 0 200 80) (rgba 0 0 0 0.5))
(image->png (canvas->image c))
```
