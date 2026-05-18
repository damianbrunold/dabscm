(define-library (scm png)
  (import (scm core) (scheme base) (scm compression) (scheme file) (srfi 151))
  (export png-encode
          png-encode-grayscale
          png-encode-rgb
          png-encode-rgba
          write-png-file
          crc32)
  (begin

    ;; --------------------------------------------------------------
    ;; Minimal PNG writer.
    ;;
    ;; Produces a valid PNG bytevector from raw 8-bit pixel data.
    ;; Supports color types 0 (grayscale), 2 (RGB), 4 (grayscale+alpha),
    ;; and 6 (RGBA), all at bit depth 8.
    ;;
    ;; Pixel layout: row-major, top-to-bottom, no padding between rows
    ;; or pixels. Sample order within a pixel matches the color type
    ;; (G, RGB, GA, or RGBA).
    ;;
    ;; All scanlines are written with filter type 0 (None). This keeps
    ;; the writer simple; the zlib step still compresses well enough
    ;; for typical use (QR codes, screenshots, sparse images). For
    ;; photo-like images a smarter filter heuristic would shrink output.
    ;; --------------------------------------------------------------

    (define crc32 (%primitive "crc32"))

    (define (samples-per-pixel color-type)
      (case color-type
        ((0) 1)   ; grayscale
        ((2) 3)   ; RGB
        ((4) 2)   ; grayscale + alpha
        ((6) 4)   ; RGBA
        (else (error "png: unsupported color type" color-type))))

    (define (u32-be! bv off n)
      (bytevector-u8-set! bv (+ off 0) (bitwise-and (arithmetic-shift n -24) #xff))
      (bytevector-u8-set! bv (+ off 1) (bitwise-and (arithmetic-shift n -16) #xff))
      (bytevector-u8-set! bv (+ off 2) (bitwise-and (arithmetic-shift n -8) #xff))
      (bytevector-u8-set! bv (+ off 3) (bitwise-and n #xff)))

    (define (chunk type data)
      ;; type: 4-char string, data: bytevector
      (let* ((dlen (bytevector-length data))
             (typebv (string->utf8 type))
             (typedata (bytevector-append typebv data))
             (crc (crc32 typedata))
             (out (make-bytevector (+ 8 dlen 4) 0)))
        (u32-be! out 0 dlen)
        (bytevector-copy! out 4 typedata 0 (bytevector-length typedata))
        (u32-be! out (+ 8 dlen) crc)
        out))

    (define png-signature
      (bytevector #x89 #x50 #x4e #x47 #x0d #x0a #x1a #x0a))

    (define (ihdr width height color-type)
      (let ((bv (make-bytevector 13 0)))
        (u32-be! bv 0 width)
        (u32-be! bv 4 height)
        (bytevector-u8-set! bv 8 8)            ; bit depth
        (bytevector-u8-set! bv 9 color-type)
        (bytevector-u8-set! bv 10 0)           ; compression: deflate
        (bytevector-u8-set! bv 11 0)           ; filter: adaptive (we use 0/None per row)
        (bytevector-u8-set! bv 12 0)           ; interlace: none
        bv))

    (define (filtered-scanlines width height pixels stride)
      ;; Prepend filter byte 0 to each row.
      (let* ((out (make-bytevector (* height (+ 1 stride)) 0)))
        (let loop ((y 0))
          (if (= y height)
              out
              (begin
                (bytevector-u8-set! out (* y (+ 1 stride)) 0)
                (bytevector-copy! out (+ 1 (* y (+ 1 stride)))
                                  pixels (* y stride) (* (+ y 1) stride))
                (loop (+ y 1)))))))

    (define (png-encode width height pixels color-type)
      "Syntax: (png-encode width height pixels color-type)
Library: (scm png)
Description: Encodes an 8-bit-per-sample image as a PNG bytevector.
  color-type is one of 0 (grayscale), 2 (RGB), 4 (grayscale+alpha), or
  6 (RGBA). pixels is a row-major bytevector of length
  width*height*samples-per-pixel.
Example:
  ;; 2x2 grayscale checkerboard
  (png-encode 2 2 (bytevector 0 255 255 0) 0)"
      (let* ((spp (samples-per-pixel color-type))
             (stride (* width spp))
             (expected (* height stride)))
        (unless (= (bytevector-length pixels) expected)
          (error "png-encode: pixel data length mismatch"
                 (bytevector-length pixels) expected))
        (let* ((raw (filtered-scanlines width height pixels stride))
               (compressed (zlib-compress raw)))
          (bytevector-append
            png-signature
            (chunk "IHDR" (ihdr width height color-type))
            (chunk "IDAT" compressed)
            (chunk "IEND" (make-bytevector 0 0))))))

    (define (png-encode-grayscale width height pixels)
      "Syntax: (png-encode-grayscale width height pixels)
Library: (scm png)
Description: Encodes 8-bit grayscale pixels (one byte per pixel, 0=black,
  255=white) as a PNG bytevector.
Example:
  (png-encode-grayscale 2 1 (bytevector 0 255))"
      (png-encode width height pixels 0))

    (define (png-encode-rgb width height pixels)
      "Syntax: (png-encode-rgb width height pixels)
Library: (scm png)
Description: Encodes 24-bit RGB pixels (three bytes per pixel in R,G,B
  order) as a PNG bytevector.
Example:
  (png-encode-rgb 1 1 (bytevector 255 0 0))   ; single red pixel"
      (png-encode width height pixels 2))

    (define (png-encode-rgba width height pixels)
      "Syntax: (png-encode-rgba width height pixels)
Library: (scm png)
Description: Encodes 32-bit RGBA pixels (four bytes per pixel in R,G,B,A
  order) as a PNG bytevector.
Example:
  (png-encode-rgba 1 1 (bytevector 255 0 0 128))"
      (png-encode width height pixels 6))

    (define (write-png-file path bv)
      "Syntax: (write-png-file path png-bytevector)
Library: (scm png)
Description: Writes a PNG bytevector (as produced by png-encode and
  friends) to the named file.
Example:
  (write-png-file \"out.png\" (png-encode-grayscale 1 1 (bytevector 0)))"
      (let ((port (open-binary-output-file path)))
        (write-bytevector bv port)
        (close-output-port port)))

    ))
