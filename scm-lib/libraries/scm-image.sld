;; (scm image) — decoding, resizing and encoding raster images.
;;
;; An image is width x height pixels of straight (not premultiplied) RGBA,
;; 8 bits per channel, rows top to bottom: the pixel format of (scm raster)
;; canvases, so images and canvases convert into each other. Decoding reads
;; PNG (every colour type and bit depth, palettes, transparency,
;; interlacing) and JPEG (baseline and progressive; grayscale, YCbCr, RGB,
;; CMYK); JPEGs are turned upright by their EXIF orientation, as browsers
;; show them. Encoding writes PNG (via (scm png)) and baseline JPEG.
;;
;; The pixel work (decoding, resizing, orientation, JPEG encoding) is
;; native code (scm-java ImageCodec.java, scm-csharp ImageCodec.cs, the
;; same algorithms); headers and EXIF are read here.

(define-library (scm image)
  (import (scheme base)
          (scheme cxr)
          (scheme file)
          (scm png)
          (only (scm raster) make-canvas canvas-width canvas-height canvas-pixels))
  (export make-image
          image?
          image-width
          image-height
          image-pixels
          image-info
          image-decode
          image-read
          image-orient
          image-resize
          image-fit
          image-crop
          image->png
          image->jpeg
          image->canvas
          canvas->image)
  (begin

    (define image-decode-rgba (%primitive "image-decode-rgba"))
    (define image-resize-rgba (%primitive "image-resize-rgba"))
    (define image-orient-rgba (%primitive "image-orient-rgba"))
    (define rgba->jpeg (%primitive "rgba->jpeg"))

    (define-record-type image
      (%make-image width height pixels)
      image?
      (width image-width)
      (height image-height)
      (pixels image-pixels))

    (define (make-image width height . pixels)
      "Syntax: (make-image width height [pixels])
Library: (scm image)
Description: An image of width x height pixels: pixels is a bytevector
  of straight RGBA, 4 bytes per pixel, rows top to bottom (default:
  transparent black). image-width, image-height and image-pixels return
  the parts; the pixels are shared, not copied.
Example:
  (image-width (make-image 3 2)) => 3"
      (let ((px (if (pair? pixels) (car pixels) (make-bytevector (* width height 4) 0))))
        (unless (and (exact-integer? width) (exact-integer? height) (> width 0) (> height 0))
          (error "make-image: bad size" width height))
        (unless (= (bytevector-length px) (* width height 4))
          (error "make-image: pixels must be width * height * 4 bytes" (bytevector-length px)))
        (%make-image width height px)))

    ;; --- headers ------------------------------------------------------

    (define (u8 bv i) (bytevector-u8-ref bv i))
    (define (u16be bv i) (+ (* 256 (u8 bv i)) (u8 bv (+ i 1))))
    (define (u32be bv i) (+ (* 65536 (u16be bv i)) (u16be bv (+ i 2))))
    (define (u16le bv i) (+ (u8 bv i) (* 256 (u8 bv (+ i 1)))))
    (define (u32le bv i) (+ (u16le bv i) (* 65536 (u16le bv (+ i 2)))))

    (define (png? bv)
      (and (>= (bytevector-length bv) 24)
           (= (u8 bv 0) #x89) (= (u8 bv 1) 80) (= (u8 bv 2) 78) (= (u8 bv 3) 71)))

    (define (jpeg? bv)
      (and (>= (bytevector-length bv) 4) (= (u8 bv 0) #xFF) (= (u8 bv 1) #xD8)))

    ;; The EXIF orientation (1-8) in an APP1 segment from start to end, or #f.
    (define (exif-orientation bv start end)
      (and (>= (- end start) 14)
           (= (u8 bv start) 69) (= (u8 bv (+ start 1)) 120)         ; "Ex"
           (= (u8 bv (+ start 2)) 105) (= (u8 bv (+ start 3)) 102)   ; "if"
           (let* ((tiff (+ start 6))
                  (le? (= (u8 bv tiff) 73))                          ; "II"
                  (r16 (lambda (i) (if le? (u16le bv i) (u16be bv i))))
                  (r32 (lambda (i) (if le? (u32le bv i) (u32be bv i))))
                  (ifd (+ tiff (r32 (+ tiff 4)))))
             (and (< (+ ifd 2) end)
                  (let ((n (r16 ifd)))
                    (let loop ((k 0))
                      (and (< k n)
                           (let ((e (+ ifd 2 (* 12 k))))
                             (and (<= (+ e 12) end)
                                  (if (= (r16 e) #x0112)
                                      (let ((o (r16 (+ e 8))))
                                        (and (<= 1 o 8) o))
                                      (loop (+ k 1))))))))))))

    ;; JPEG: (width height orientation) from the frame header and EXIF.
    (define (jpeg-header bv)
      (let ((n (bytevector-length bv)))
        (let loop ((i 2) (orientation 1))
          (cond
            ((>= (+ i 4) n) #f)
            ((not (= (u8 bv i) #xFF)) (loop (+ i 1) orientation))
            (else
             (let ((m (u8 bv (+ i 1))))
               (cond
                 ((or (= m #xFF) (= m #x01) (<= #xD0 m #xD7)) (loop (+ i 1) orientation))
                 ((or (= m #xD9) (= m #xDA)) #f)
                 (else
                  (let ((len (u16be bv (+ i 2))))
                    (cond
                      ((and (<= #xC0 m #xCF) (not (memv m '(#xC4 #xC8 #xCC))))
                       (and (< (+ i 8) n)
                            (list (u16be bv (+ i 7)) (u16be bv (+ i 5)) orientation)))
                      ((= m #xE1)
                       (loop (+ i 2 len)
                             (or (exif-orientation bv (+ i 4) (min n (+ i 2 len))) orientation)))
                      (else (loop (+ i 2 len) orientation))))))))))))

    (define (image-info bv)
      "Syntax: (image-info bytevector)
Library: (scm image)
Description: What the headers of an image file say, without decoding
  it: an alist ((format . png | jpeg) (width . w) (height . h)
  (orientation . 1-8)), width and height as stored (before orientation),
  or #f if bytevector is not a PNG or JPEG.
Example:
  (image-info (image->png (make-image 3 2)))
  => ((format . png) (width . 3) (height . 2) (orientation . 1))"
      (cond
        ((png? bv)
         `((format . png) (width . ,(u32be bv 16)) (height . ,(u32be bv 20)) (orientation . 1)))
        ((jpeg? bv)
         (let ((h (jpeg-header bv)))
           (and h `((format . jpeg) (width . ,(car h)) (height . ,(cadr h))
                    (orientation . ,(caddr h))))))
        (else #f)))

    ;; --- decoding -----------------------------------------------------

    (define (opt opts key default)
      (let ((p (assq key opts))) (if p (cdr p) default)))

    (define default-max-pixels 50000000)

    (define (image-decode bv . opts)
      "Syntax: (image-decode bytevector [option ...])
Library: (scm image)
Description: Decodes a PNG or JPEG image. Options: (max-pixels . n)
  refuses images of more than n pixels before decoding them (default
  50 000 000: about 200 MB of pixels); (orient . #f) keeps a JPEG as
  stored instead of turning it upright by its EXIF orientation. Signals
  an error for data that is not a well-formed PNG or JPEG, or uses what
  the decoder does not support (arithmetic coding, lossless JPEG, 12-bit
  samples).
Example:
  (image-width (image-decode (image->png (make-image 3 2)))) => 3"
      (let* ((max-pixels (opt opts 'max-pixels default-max-pixels))
             (r (image-decode-rgba bv max-pixels))
             (img (%make-image (car r) (cadr r) (caddr r)))
             (info (and (opt opts 'orient #t) (jpeg? bv) (image-info bv)))
             (o (if info (cdr (assq 'orientation info)) 1)))
        (if (= o 1) img (image-orient img o))))

    (define (read-file path)
      (call-with-port (open-binary-input-file path)
        (lambda (p)
          (let loop ((chunks '()))
            (let ((b (read-bytevector 65536 p)))
              (if (eof-object? b)
                  (apply bytevector-append (reverse chunks))
                  (loop (cons b chunks))))))))

    (define (image-read path . opts)
      "Syntax: (image-read path [option ...])
Library: (scm image)
Description: Reads and decodes the PNG or JPEG file at path; options as
  for image-decode.
Example:
  (image-width (image-read \"photo.jpg\")) => 4032"
      (apply image-decode (read-file path) opts))

    ;; --- transformations ----------------------------------------------

    (define (image-orient img orientation)
      "Syntax: (image-orient image orientation)
Library: (scm image)
Description: The image turned and mirrored by an EXIF orientation: 1 as
  is, 2 mirrored, 3 turned 180 degrees, 4 flipped, 5 transposed, 6 turned
  90 degrees clockwise, 7 transversed, 8 turned 90 degrees
  counterclockwise. 5 to 8 swap width and height.
Example:
  (image-width (image-orient (make-image 3 2) 6)) => 2"
      (if (= orientation 1)
          img
          (let ((px (image-orient-rgba (image-pixels img) (image-width img) (image-height img) orientation)))
            (if (>= orientation 5)
                (%make-image (image-height img) (image-width img) px)
                (%make-image (image-width img) (image-height img) px)))))

    (define (image-resize img width height . method)
      "Syntax: (image-resize image width height [method])
Library: (scm image)
Description: The image scaled to width x height pixels. method is 'box
  (each new pixel the average of the area it covers: sharp, right for
  shrinking) or 'bilinear (smoother, right for enlarging); the default is
  'box when the image shrinks in both directions, else 'bilinear.
  Transparent pixels do not darken their neighbours.
Example:
  (image-height (image-resize (make-image 400 300) 200 150)) => 150"
      (unless (and (exact-integer? width) (exact-integer? height) (> width 0) (> height 0))
        (error "image-resize: bad size" width height))
      (let ((m (if (pair? method)
                   (car method)
                   (if (and (<= width (image-width img)) (<= height (image-height img))) 'box 'bilinear))))
        (if (and (= width (image-width img)) (= height (image-height img)))
            img
            (%make-image width height
                         (image-resize-rgba (image-pixels img) (image-width img) (image-height img)
                                            width height m)))))

    (define (image-fit img max-width max-height)
      "Syntax: (image-fit image max-width max-height)
Library: (scm image)
Description: The image shrunk to fit into max-width x max-height,
  keeping its aspect ratio (each side at least 1 pixel); an image that
  fits already is returned as it is, never enlarged. For thumbnails and
  downscaled copies.
Example:
  (let ((t (image-fit (make-image 4000 3000) 400 400)))
    (list (image-width t) (image-height t)))  => (400 300)"
      (let ((w (image-width img)) (h (image-height img)))
        (if (and (<= w max-width) (<= h max-height))
            img
            (let ((s (min (/ max-width w) (/ max-height h))))
              (image-resize img
                            (max 1 (min max-width (exact (round (* w s)))))
                            (max 1 (min max-height (exact (round (* h s))))))))))

    (define (image-crop img x y width height)
      "Syntax: (image-crop image x y width height)
Library: (scm image)
Description: The width x height part of the image whose top-left pixel
  is at column x, row y. The part must lie within the image.
Example:
  (image-width (image-crop (make-image 10 10) 2 2 5 3)) => 5"
      (unless (and (exact-integer? x) (exact-integer? y) (exact-integer? width) (exact-integer? height)
                   (>= x 0) (>= y 0) (> width 0) (> height 0)
                   (<= (+ x width) (image-width img)) (<= (+ y height) (image-height img)))
        (error "image-crop: the part is not within the image" x y width height))
      (let ((src (image-pixels img))
            (dst (make-bytevector (* width height 4)))
            (stride (* 4 (image-width img))))
        (do ((row 0 (+ row 1))) ((= row height))
          (let ((s (+ (* (+ y row) stride) (* 4 x))))
            (bytevector-copy! dst (* row width 4) src s (+ s (* 4 width)))))
        (%make-image width height dst)))

    ;; --- encoding and canvases ----------------------------------------

    (define (image->png img)
      "Syntax: (image->png image)
Library: (scm image)
Description: The image as a PNG file (bytevector, RGBA).
Example:
  (bytevector-u8-ref (image->png (make-image 1 1)) 1) => 80"
      (png-encode-rgba (image-width img) (image-height img) (image-pixels img)))

    (define (image->jpeg img . quality)
      "Syntax: (image->jpeg image [quality])
Library: (scm image)
Description: The image as a baseline JPEG file (bytevector) at quality 1
  to 100 (default 85); transparent parts become white.
Example:
  (bytevector-u8-ref (image->jpeg (make-image 8 8)) 0) => 255"
      (rgba->jpeg (image-pixels img) (image-width img) (image-height img)
                  (if (pair? quality) (car quality) 85)))

    (define (image->canvas img)
      "Syntax: (image->canvas image)
Library: (scm image)
Description: A (scm raster) canvas with a copy of the image's pixels, to
  draw on.
Example:
  (canvas-width (image->canvas (make-image 3 2))) => 3"
      (let ((c (make-canvas (image-width img) (image-height img))))
        (bytevector-copy! (canvas-pixels c) 0 (image-pixels img))
        c))

    (define (canvas->image canvas)
      "Syntax: (canvas->image canvas)
Library: (scm image)
Description: An image with a copy of a (scm raster) canvas's pixels.
Example:
  (image-height (canvas->image (make-canvas 3 2))) => 2"
      (%make-image (canvas-width canvas) (canvas-height canvas)
                   (bytevector-copy (canvas-pixels canvas))))))
