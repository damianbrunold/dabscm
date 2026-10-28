;; (scm truetype) — TrueType fonts: glyph outlines, advances, kerning, and
;; text as paths for (scm raster).
;;
;; read-truetype parses a .ttf held in a bytevector: the cmap (formats 4
;; and 12), hmtx, loca and glyf (simple and composite glyphs), and the
;; format 0 kern table when there is one. Glyphs are decoded on first use.
;; make-outline-font builds the same kind of font from glyph data already
;; extracted, which is how (scm fonts dejavu) ships its fonts without a
;; .ttf file.
;;
;; A glyph is (advance . contours): advance in font units, contours a list
;; of lists of (x y on-curve?) in font units, y pointing up. Hinting
;; instructions are ignored.

(define-library (scm truetype)
  (export read-truetype
          make-outline-font
          font?
          font-units-per-em
          font-ascent
          font-descent
          font-glyph
          font-kerning
          font-text-width
          font-text-path)
  (import (scheme base)
          (scheme char)
          (scheme inexact)
          (scheme cxr)
          (srfi 69)
          (scm bytevector))
  (begin

    ;; lookup: char -> glyph or #f; kern: (char char) -> font units
    (define-record-type font
      (%make-font units-per-em ascent descent lookup kern)
      font?
      (units-per-em font-units-per-em)
      (ascent font-ascent)
      (descent font-descent)
      (lookup font-lookup)
      (kern font-kern))

    (define (font-glyph font char)
      "Syntax: (font-glyph font char)
Library: (scm truetype)
Description: Returns the glyph for char as (advance . contours), or #f
  when the font has none. advance is in font units; contours is a list of
  contours, each a list of points (x y on-curve?) in font units with y
  pointing up, as TrueType stores them.
Example:
  (car (font-glyph font #\\A)) => 1401   ; DejaVu Sans"
      ((font-lookup font) char))

    (define (font-kerning font left right)
      "Syntax: (font-kerning font left right)
Library: (scm truetype)
Description: Returns the kerning adjustment between the characters left
  and right, in font units (usually negative), or 0.
Example:
  (font-kerning font #\\A #\\V) => -77   ; DejaVu Sans"
      ((font-kern font) left right))

    ;; --- reading big-endian values ------------------------------------

    (define (u8 bv o) (bytevector-u8-ref bv o))
    (define (u16 bv o) (bytevector-u16-ref bv o 'big))
    (define (s16 bv o) (bytevector-s16-ref bv o 'big))
    (define (u32 bv o) (bytevector-u32-ref bv o 'big))
    (define (s8 bv o) (let ((v (u8 bv o))) (if (> v 127) (- v 256) v)))
    (define (f2dot14 bv o) (/ (s16 bv o) 16384.0))

    (define (tag bv o)
      (string (integer->char (u8 bv o)) (integer->char (u8 bv (+ o 1)))
              (integer->char (u8 bv (+ o 2))) (integer->char (u8 bv (+ o 3)))))

    ;; -> alist tag -> (offset . length)
    (define (table-directory bv)
      (let ((n (u16 bv 4)))
        (let loop ((i 0) (acc '()))
          (if (= i n)
              acc
              (let ((r (+ 12 (* 16 i))))
                (loop (+ i 1)
                      (cons (cons (tag bv r) (cons (u32 bv (+ r 8)) (u32 bv (+ r 12))))
                            acc)))))))

    (define (table tables name)
      (let ((p (assoc name tables)))
        (if p (cadr p) (error "read-truetype: missing table" name))))

    ;; --- cmap -----------------------------------------------------------

    ;; -> procedure code-point -> glyph id (0 when unmapped)
    (define (cmap-lookup bv cmap)
      (let* ((n (u16 bv (+ cmap 2)))
             (subtables
              (let loop ((i 0) (acc '()))
                (if (= i n)
                    (reverse acc)
                    (let ((r (+ cmap 4 (* 8 i))))
                      (loop (+ i 1)
                            (cons (list (u16 bv r) (u16 bv (+ r 2))
                                        (+ cmap (u32 bv (+ r 4))))
                                  acc))))))
             (find (lambda (fmt ok?)
                     (let loop ((s subtables))
                       (cond ((null? s) #f)
                             ((and (ok? (caar s) (cadar s))
                                   (= (u16 bv (caddar s)) fmt))
                              (caddar s))
                             (else (loop (cdr s))))))))
        (cond
         ((find 12 (lambda (p e) (or (and (= p 3) (= e 10)) (= p 0))))
          => (lambda (o) (cmap12 bv o)))
         ((find 4 (lambda (p e) (or (and (= p 3) (memv e '(0 1))) (= p 0))))
          => (lambda (o) (cmap4 bv o)))
         (else (error "read-truetype: no usable cmap")))))

    (define (cmap4 bv o)
      (let* ((segs (/ (u16 bv (+ o 6)) 2))
             (ends (+ o 14))
             (starts (+ ends (* 2 segs) 2))
             (deltas (+ starts (* 2 segs)))
             (ranges (+ deltas (* 2 segs))))
        (lambda (c)
          (let loop ((i 0))
            (cond
             ((= i segs) 0)
             ((> c (u16 bv (+ ends (* 2 i)))) (loop (+ i 1)))
             (else
              (let ((start (u16 bv (+ starts (* 2 i)))))
                (if (< c start)
                    0
                    (let ((ro (u16 bv (+ ranges (* 2 i))))
                          (delta (u16 bv (+ deltas (* 2 i)))))
                      (if (= ro 0)
                          (modulo (+ c delta) 65536)
                          (let ((g (u16 bv (+ ranges (* 2 i) ro (* 2 (- c start))))))
                            (if (= g 0) 0 (modulo (+ g delta) 65536)))))))))))))

    (define (cmap12 bv o)
      (let ((n (u32 bv (+ o 12))))
        (lambda (c)
          (let loop ((i 0))
            (if (= i n)
                0
                (let* ((g (+ o 16 (* 12 i)))
                       (start (u32 bv g)) (end (u32 bv (+ g 4))))
                  (cond ((< c start) 0)
                        ((<= c end) (+ (u32 bv (+ g 8)) (- c start)))
                        (else (loop (+ i 1))))))))))

    ;; --- glyf -----------------------------------------------------------

    ;; -> list of contours of (x y on?), composites resolved
    (define (glyph-contours bv glyf loca long-loca? gid)
      (let* ((at (lambda (i) (if long-loca?
                                 (u32 bv (+ loca (* 4 i)))
                                 (* 2 (u16 bv (+ loca (* 2 i)))))))
             (start (at gid)) (end (at (+ gid 1))))
        (if (= start end)
            '()                         ; an empty glyph, such as space
            (let* ((o (+ glyf start))
                   (n (s16 bv o)))
              (if (>= n 0)
                  (simple-glyph bv o n)
                  (composite-glyph bv glyf loca long-loca? o))))))

    (define (simple-glyph bv o ncontours)
      (let* ((ends (let loop ((i 0) (acc '()))
                     (if (= i ncontours)
                         (reverse acc)
                         (loop (+ i 1) (cons (u16 bv (+ o 10 (* 2 i))) acc)))))
             (npoints (if (null? ends) 0 (+ 1 (apply max ends))))
             (ilen (u16 bv (+ o 10 (* 2 ncontours))))
             (fo (+ o 12 (* 2 ncontours) ilen))
             (flags (make-vector npoints 0)))
        ;; flags, with repeats
        (let loop ((i 0) (p fo))
          (if (< i npoints)
              (let ((f (u8 bv p)))
                (if (odd? (quotient f 8))
                    (let ((r (u8 bv (+ p 1))))
                      (do ((k 0 (+ k 1))) ((or (> k r) (>= (+ i k) npoints)))
                        (vector-set! flags (+ i k) f))
                      (loop (+ i r 1) (+ p 2)))
                    (begin (vector-set! flags i f) (loop (+ i 1) (+ p 1)))))
              ;; coordinates: x then y, deltas
              (let* ((xs (make-vector npoints 0))
                     (ys (make-vector npoints 0))
                     (read-coords!
                      (lambda (p vec short-bit same-bit)
                        (let loop ((i 0) (p p) (v 0))
                          (if (= i npoints)
                              p
                              (let ((f (vector-ref flags i)))
                                (cond
                                 ((odd? (quotient f short-bit))
                                  (let ((d (u8 bv p)))
                                    (let ((v (if (odd? (quotient f same-bit)) (+ v d) (- v d))))
                                      (vector-set! vec i v)
                                      (loop (+ i 1) (+ p 1) v))))
                                 ((odd? (quotient f same-bit))
                                  (vector-set! vec i v)
                                  (loop (+ i 1) p v))
                                 (else
                                  (let ((v (+ v (s16 bv p))))
                                    (vector-set! vec i v)
                                    (loop (+ i 1) (+ p 2) v)))))))))
                     (yp (read-coords! p xs 2 16)))
                (read-coords! yp ys 4 32)
                (let loop ((ends ends) (first 0) (acc '()))
                  (if (null? ends)
                      (reverse acc)
                      (loop (cdr ends) (+ (car ends) 1)
                            (cons (let pts ((i (car ends)) (c '()))
                                    (if (< i first)
                                        c
                                        (pts (- i 1)
                                             (cons (list (vector-ref xs i) (vector-ref ys i)
                                                         (odd? (vector-ref flags i)))
                                                   c))))
                                  acc)))))))))

    (define (composite-glyph bv glyf loca long-loca? o)
      (let loop ((p (+ o 10)) (acc '()))
        (let* ((flags (u16 bv p))
               (gid (u16 bv (+ p 2)))
               (words? (odd? flags))
               (xy? (odd? (quotient flags 2)))
               (dx (if words? (s16 bv (+ p 4)) (s8 bv (+ p 4))))
               (dy (if words? (s16 bv (+ p 6)) (s8 bv (+ p 5))))
               (p (+ p 4 (if words? 4 2))))
          (let-values (((a b c d p)
                        (cond
                         ((odd? (quotient flags 8))       ; one scale
                          (let ((s (f2dot14 bv p))) (values s 0.0 0.0 s (+ p 2))))
                         ((odd? (quotient flags 64))      ; x and y scale
                          (values (f2dot14 bv p) 0.0 0.0 (f2dot14 bv (+ p 2)) (+ p 4)))
                         ((odd? (quotient flags 128))     ; 2 x 2
                          (values (f2dot14 bv p) (f2dot14 bv (+ p 2))
                                  (f2dot14 bv (+ p 4)) (f2dot14 bv (+ p 6)) (+ p 8)))
                         (else (values 1.0 0.0 0.0 1.0 p)))))
            (let* ((dx (if xy? dx 0)) (dy (if xy? dy 0))
                   (part (map (lambda (contour)
                                (map (lambda (pt)
                                       (let ((x (car pt)) (y (cadr pt)))
                                         (list (+ (* a x) (* c y) dx) (+ (* b x) (* d y) dy)
                                               (caddr pt))))
                                     contour))
                              (glyph-contours bv glyf loca long-loca? gid)))
                   (acc (append acc part)))
              (if (odd? (quotient flags 32))         ; more components
                  (loop p acc)
                  acc))))))

    ;; --- kern -----------------------------------------------------------

    ;; -> hash table (left-gid . right-gid) -> value, from the first
    ;; horizontal format 0 subtable
    (define (kern-pairs bv tables)
      (let ((h (make-hash-table equal?))
            (k (assoc "kern" tables)))
        (when k
          (let* ((o (cadr k))
                 (ntables (u16 bv (+ o 2))))
            (let loop ((i 0) (st (+ o 4)))
              (when (< i ntables)
                (let ((len (u16 bv (+ st 2)))
                      (coverage (u16 bv (+ st 4))))
                  (if (and (= (quotient coverage 256) 0) (odd? coverage))
                      (let ((npairs (u16 bv (+ st 6))))
                        (do ((j 0 (+ j 1))) ((= j npairs))
                          (let ((r (+ st 14 (* 6 j))))
                            (hash-table-set! h (cons (u16 bv r) (u16 bv (+ r 2)))
                                             (s16 bv (+ r 4))))))
                      (loop (+ i 1) (+ st len))))))))
        h))

    ;; --- fonts ----------------------------------------------------------

    (define (read-truetype bv)
      "Syntax: (read-truetype bytevector)
Library: (scm truetype)
Description: Parses a TrueType font (.ttf) and returns a font. Glyph
  outlines are decoded when first asked for. OpenType fonts with CFF
  outlines (.otf) are not supported.
Example:
  (define font (read-truetype (call-with-port
                 (open-binary-input-file \"DejaVuSans.ttf\")
                 (lambda (p) (read-bytevector 1000000 p)))))"
      (let* ((tables (table-directory bv))
             (head (table tables "head"))
             (hhea (table tables "hhea"))
             (hmtx (table tables "hmtx"))
             (nmetrics (u16 bv (+ hhea 34)))
             (glyf (table tables "glyf"))
             (loca (table tables "loca"))
             (long-loca? (= 1 (s16 bv (+ head 50))))
             (gid-of (cmap-lookup bv (table tables "cmap")))
             (advance (lambda (gid)
                        (u16 bv (+ hmtx (* 4 (min gid (- nmetrics 1)))))))
             (cache (make-hash-table eqv?))
             (pairs (kern-pairs bv tables)))
        (%make-font
         (u16 bv (+ head 18))
         (s16 bv (+ hhea 4))
         (s16 bv (+ hhea 6))
         (lambda (char)
           (let ((gid (gid-of (char->integer char))))
             (and (> gid 0)
                  (or (hash-table-ref/default cache gid #f)
                      (let ((g (cons (advance gid)
                                     (glyph-contours bv glyf loca long-loca? gid))))
                        (hash-table-set! cache gid g)
                        g)))))
         (lambda (left right)
           (hash-table-ref/default
            pairs (cons (gid-of (char->integer left)) (gid-of (char->integer right))) 0)))))

    (define (make-outline-font units-per-em ascent descent glyphs . kerning)
      "Syntax: (make-outline-font units-per-em ascent descent glyphs [kerning])
Library: (scm truetype)
Description: Returns a font made from glyph data: glyphs is an alist of
  (char advance . contours), as font-glyph returns them; kerning an alist
  of ((left . right) . value). For fonts compiled into a library, such as
  (scm fonts dejavu).
Example:
  (make-outline-font 1000 800 -200
    (list (list #\\- 400 '((50 250 #t) (350 250 #t) (350 300 #t) (50 300 #t)))))"
      (let ((h (make-hash-table eqv?))
            (k (make-hash-table equal?)))
        (for-each (lambda (g) (hash-table-set! h (car g) (cdr g))) glyphs)
        (when (pair? kerning)
          (for-each (lambda (p) (hash-table-set! k (car p) (cdr p))) (car kerning)))
        (%make-font units-per-em ascent descent
                    (lambda (char) (hash-table-ref/default h char #f))
                    (lambda (left right)
                      (hash-table-ref/default k (cons left right) 0)))))

    ;; --- text -----------------------------------------------------------

    ;; A missing character is drawn as "?" when the font has one, else
    ;; left out.
    (define (glyph-or-fallback font c)
      (or (font-glyph font c) (font-glyph font #\?)))

    (define (font-text-width font size string)
      "Syntax: (font-text-width font size string)
Library: (scm truetype)
Description: Returns the advance width of string set in font at size
  (in pixels per em), kerning included.
Example:
  (font-text-width font 11 \"Intern\") => 33.4..."
      (let ((s (/ (inexact size) (font-units-per-em font))))
        (let loop ((cs (string->list string)) (w 0))
          (if (null? cs)
              (* s w)
              (let ((g (glyph-or-fallback font (car cs))))
                (loop (cdr cs)
                      (+ w (if g (car g) 0)
                         (if (pair? (cdr cs)) (font-kerning font (car cs) (cadr cs)) 0))))))))

    (define (font-text-path font size x y string)
      "Syntax: (font-text-path font size x y string)
Library: (scm truetype)
Description: Returns string set in font at size (pixels per em) as a path
  for (scm raster), starting at x on the baseline y, in canvas coordinates
  (y pointing down). Fill it with the non-zero rule.
Example:
  (canvas-fill-path! canvas (font-text-path font 11 10 20 \"Intern\")
                     (rgba 0 0 0))"
      (let ((s (/ (inexact size) (font-units-per-em font))))
        (let loop ((cs (string->list string)) (pen 0) (acc '()))
          (if (null? cs)
              (apply append (reverse acc))
              (let* ((g (glyph-or-fallback font (car cs)))
                     (ox (+ x (* s pen)))
                     (path (if g (contours->path (cdr g) ox y s) '())))
                (loop (cdr cs)
                      (+ pen (if g (car g) 0)
                         (if (pair? (cdr cs)) (font-kerning font (car cs) (cadr cs)) 0))
                      (cons path acc)))))))

    ;; TrueType contours are quadratic: between two off-curve points lies
    ;; an implied on-curve point at their midpoint.
    (define (contours->path contours ox oy s)
      (let ((pt (lambda (p) (list (+ ox (* s (car p))) (- oy (* s (cadr p))))))
            (mid (lambda (a b) (list (/ (+ (car a) (car b)) 2) (/ (+ (cadr a) (cadr b)) 2) #t))))
        (apply append
               (map (lambda (contour)
                      (if (null? contour)
                          '()
                          ;; start on an on-curve point, or the midpoint of
                          ;; the first two when there is none
                          (let* ((on (let find ((c contour))
                                       (cond ((null? c) #f) ((caddr (car c)) c) (else (find (cdr c))))))
                                 (rot (if on
                                          (append on (list-head contour (- (length contour) (length on))))
                                          (cons (mid (car contour) (cadr contour)) contour)))
                                 (start (car rot)))
                            (let walk ((ps (append (cdr rot) (list start)))
                                       (ctrl #f)
                                       (acc (list (cons 'M (pt start)))))
                              (if (null? ps)
                                  (reverse (cons '(Z) acc))
                                  (let ((p (car ps)))
                                    (cond
                                     ((caddr p)
                                      (walk (cdr ps) #f
                                            (cons (if ctrl
                                                      (append '(Q) (pt ctrl) (pt p))
                                                      (cons 'L (pt p)))
                                                  acc)))
                                     (ctrl
                                      (let ((m (mid ctrl p)))
                                        (walk (cdr ps) p (cons (append '(Q) (pt ctrl) (pt m)) acc))))
                                     (else (walk (cdr ps) p acc)))))))))
                    contours))))

    (define (list-head l k)
      (if (= k 0) '() (cons (car l) (list-head (cdr l) (- k 1)))))

))
