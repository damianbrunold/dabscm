# `(scm image)`

Image decoding (PNG, JPEG), resizing, cropping, EXIF orientation, PNG and JPEG encoding

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


## Exports

### `canvas->image`

```
Syntax: (canvas->image canvas)
Library: (scm image)
Description: An image with a copy of a (scm raster) canvas's pixels.
Example:
  (image-height (canvas->image (make-canvas 3 2))) => 2
```

### `image->canvas`

```
Syntax: (image->canvas image)
Library: (scm image)
Description: A (scm raster) canvas with a copy of the image's pixels, to
  draw on.
Example:
  (canvas-width (image->canvas (make-image 3 2))) => 3
```

### `image->jpeg`

```
Syntax: (image->jpeg image [quality])
Library: (scm image)
Description: The image as a baseline JPEG file (bytevector) at quality 1
  to 100 (default 85); transparent parts become white.
Example:
  (bytevector-u8-ref (image->jpeg (make-image 8 8)) 0) => 255
```

### `image->png`

```
Syntax: (image->png image)
Library: (scm image)
Description: The image as a PNG file (bytevector, RGBA).
Example:
  (bytevector-u8-ref (image->png (make-image 1 1)) 1) => 80
```

### `image-crop`

```
Syntax: (image-crop image x y width height)
Library: (scm image)
Description: The width x height part of the image whose top-left pixel
  is at column x, row y. The part must lie within the image.
Example:
  (image-width (image-crop (make-image 10 10) 2 2 5 3)) => 5
```

### `image-decode`

```
Syntax: (image-decode bytevector [option ...])
Library: (scm image)
Description: Decodes a PNG or JPEG image. Options: (max-pixels . n)
  refuses images of more than n pixels before decoding them (default
  50 000 000: about 200 MB of pixels); (orient . #f) keeps a JPEG as
  stored instead of turning it upright by its EXIF orientation. Signals
  an error for data that is not a well-formed PNG or JPEG, or uses what
  the decoder does not support (arithmetic coding, lossless JPEG, 12-bit
  samples).
Example:
  (image-width (image-decode (image->png (make-image 3 2)))) => 3
```

### `image-fit`

```
Syntax: (image-fit image max-width max-height)
Library: (scm image)
Description: The image shrunk to fit into max-width x max-height,
  keeping its aspect ratio (each side at least 1 pixel); an image that
  fits already is returned as it is, never enlarged. For thumbnails and
  downscaled copies.
Example:
  (let ((t (image-fit (make-image 4000 3000) 400 400)))
    (list (image-width t) (image-height t)))  => (400 300)
```

### `image-height`

*(no documentation)*

### `image-info`

```
Syntax: (image-info bytevector)
Library: (scm image)
Description: What the headers of an image file say, without decoding
  it: an alist ((format . png | jpeg) (width . w) (height . h)
  (orientation . 1-8)), width and height as stored (before orientation),
  or #f if bytevector is not a PNG or JPEG.
Example:
  (image-info (image->png (make-image 3 2)))
  => ((format . png) (width . 3) (height . 2) (orientation . 1))
```

### `image-orient`

```
Syntax: (image-orient image orientation)
Library: (scm image)
Description: The image turned and mirrored by an EXIF orientation: 1 as
  is, 2 mirrored, 3 turned 180 degrees, 4 flipped, 5 transposed, 6 turned
  90 degrees clockwise, 7 transversed, 8 turned 90 degrees
  counterclockwise. 5 to 8 swap width and height.
Example:
  (image-width (image-orient (make-image 3 2) 6)) => 2
```

### `image-pixels`

*(no documentation)*

### `image-read`

```
Syntax: (image-read path [option ...])
Library: (scm image)
Description: Reads and decodes the PNG or JPEG file at path; options as
  for image-decode.
Example:
  (image-width (image-read "photo.jpg")) => 4032
```

### `image-resize`

```
Syntax: (image-resize image width height [method])
Library: (scm image)
Description: The image scaled to width x height pixels. method is 'box
  (each new pixel the average of the area it covers: sharp, right for
  shrinking) or 'bilinear (smoother, right for enlarging); the default is
  'box when the image shrinks in both directions, else 'bilinear.
  Transparent pixels do not darken their neighbours.
Example:
  (image-height (image-resize (make-image 400 300) 200 150)) => 150
```

### `image-width`

*(no documentation)*

### `image?`

*(no documentation)*

### `make-image`

```
Syntax: (make-image width height [pixels])
Library: (scm image)
Description: An image of width x height pixels: pixels is a bytevector
  of straight RGBA, 4 bytes per pixel, rows top to bottom (default:
  transparent black). image-width, image-height and image-pixels return
  the parts; the pixels are shared, not copied.
Example:
  (image-width (make-image 3 2)) => 3
```

