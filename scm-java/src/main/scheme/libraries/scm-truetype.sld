;; (scm truetype) — TrueType fonts: glyph outlines, advances, kerning, and
;; text as paths for (scm raster).
;;
;; read-truetype parses a .ttf held in a bytevector: the cmap (formats 4
;; and 12), hmtx, loca and glyf (simple and composite glyphs), and the
;; kerning: the format 0 kern table when there is one, else the pair
;; adjustments of the GPOS kern feature (lookup type 2, both formats). Glyphs are decoded on first use.
;; OpenType features that substitute one glyph for another (GSUB lookup
;; type 1, also behind an extension lookup) can be switched on: stylistic
;; sets, character variants, tabular figures.
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
          font-text-path
          font-chars
          font->truetype)
  (import (scheme base)
          (scheme char)
          (scheme inexact)
          (scheme cxr)
          (srfi 69)
          (scm bytevector))
  (begin

    ;; lookup: char -> glyph or #f; kern: (char char) -> font units;
    ;; chars: the characters with glyphs, ascending, when known (fonts
    ;; made from glyph data), else #f.
    (define-record-type font
      (%make-font units-per-em ascent descent lookup kern chars)
      font?
      (units-per-em font-units-per-em)
      (ascent font-ascent)
      (descent font-descent)
      (lookup font-lookup)
      (kern font-kern)
      (chars %font-chars))

    (define (font-chars font)
      "Syntax: (font-chars font)
Library: (scm truetype)
Description: The characters font has glyphs for, ascending, or #f when
  the font does not list them (fonts read with read-truetype).
Example:
  (length (font-chars inter-regular)) => 312"
      (%font-chars font))

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

    ;; --- GSUB -----------------------------------------------------------

    ;; -> hash table gid -> gid: the single substitutions (lookup type 1,
    ;; directly or through an extension, type 7) of the features named in
    ;; tags, in every script and language system that has them. Lookups of
    ;; other types are not applied.
    (define (gsub-singles bv tables tags)
      (let ((h (make-hash-table eqv?))
            (g (assoc "GSUB" tables)))
        (when (and g (pair? tags))
          (let* ((o (cadr g))
                 (fl (+ o (u16 bv (+ o 6))))
                 (ll (+ o (u16 bv (+ o 8))))
                 (lookups
                  (let loop ((i 0) (acc '()))
                    (if (= i (u16 bv fl))
                        acc
                        (let* ((r (+ fl 2 (* 6 i)))
                               (ft (+ fl (u16 bv (+ r 4)))))
                          (loop (+ i 1)
                                (if (member (tag bv r) tags)
                                    (append acc
                                            (map (lambda (k) (u16 bv (+ ft 4 (* 2 k))))
                                                 (iota-list (u16 bv (+ ft 2)))))
                                    acc)))))))
            (for-each
             (lambda (li)
               (let* ((lk (+ ll (u16 bv (+ ll 2 (* 2 li)))))
                      (type (u16 bv lk)))
                 (for-each
                  (lambda (k)
                    (let* ((st (+ lk (u16 bv (+ lk 6 (* 2 k))))))
                      (cond
                       ((= type 1) (single-subst! h bv st))
                       ((and (= type 7) (= 1 (u16 bv (+ st 2))))
                        (single-subst! h bv (+ st (u32 bv (+ st 4))))))))
                  (iota-list (u16 bv (+ lk 4))))))
             lookups)))
        h))

    (define (iota-list n) (let loop ((i (- n 1)) (acc '())) (if (< i 0) acc (loop (- i 1) (cons i acc)))))

    (define (single-subst! h bv st)
      (let ((format (u16 bv st))
            (covered (coverage bv (+ st (u16 bv (+ st 2))))))
        (for-each
         (lambda (pair)                ; (gid . coverage index)
           (hash-table-set!
            h (car pair)
            (if (= format 1)
                (modulo (+ (car pair) (s16 bv (+ st 4))) 65536)
                (u16 bv (+ st 6 (* 2 (cdr pair)))))))
         covered)))

    ;; -> list of (gid . coverage index)
    (define (coverage bv o)
      (if (= 1 (u16 bv o))
          (map (lambda (i) (cons (u16 bv (+ o 4 (* 2 i))) i)) (iota-list (u16 bv (+ o 2))))
          (apply append
                 (map (lambda (i)
                        (let* ((r (+ o 4 (* 6 i)))
                               (start (u16 bv r)) (end (u16 bv (+ r 2))) (ci (u16 bv (+ r 4))))
                          (map (lambda (k) (cons (+ start k) (+ ci k)))
                               (iota-list (+ 1 (- end start))))))
                      (iota-list (u16 bv (+ o 2)))))))

    ;; --- GPOS kerning ---------------------------------------------------

    ;; -> procedure (left-gid right-gid) -> x advance adjustment, from the
    ;; pair adjustment lookups (type 2, or 9 wrapping 2) of the kern
    ;; feature; #f when there are none. As OpenType applies them: the
    ;; first subtable that covers the left glyph and has the pair decides.
    (define (gpos-kerning bv tables)
      (let ((g (assoc "GPOS" tables)))
        (and g
             (let* ((o (cadr g))
                    (fl (+ o (u16 bv (+ o 6))))
                    (ll (+ o (u16 bv (+ o 8))))
                    (indices
                     (delete-dups
                      (let loop ((i 0) (acc '()))
                        (if (= i (u16 bv fl))
                            acc
                            (let* ((r (+ fl 2 (* 6 i)))
                                   (ft (+ fl (u16 bv (+ r 4)))))
                              (loop (+ i 1)
                                    (if (string=? (tag bv r) "kern")
                                        (append acc (map (lambda (k) (u16 bv (+ ft 4 (* 2 k))))
                                                         (iota-list (u16 bv (+ ft 2)))))
                                        acc)))))))
                    (subtables
                     (apply append
                            (map (lambda (li)
                                   (let* ((lk (+ ll (u16 bv (+ ll 2 (* 2 li)))))
                                          (type (u16 bv lk)))
                                     (filter-map-list
                                      (lambda (k)
                                        (let ((st (+ lk (u16 bv (+ lk 6 (* 2 k))))))
                                          (cond ((= type 2) (pair-subtable bv st))
                                                ((and (= type 9) (= 2 (u16 bv (+ st 2))))
                                                 (pair-subtable bv (+ st (u32 bv (+ st 4)))))
                                                (else #f))))
                                      (iota-list (u16 bv (+ lk 4))))))
                                 indices))))
               (and (pair? subtables)
                    (lambda (l r)
                      (let loop ((ss subtables))
                        (if (null? ss)
                            0
                            (let ((v ((car ss) l r)))
                              (if v v (loop (cdr ss))))))))))))

    (define (delete-dups l)
      (let loop ((l l) (acc '()))
        (cond ((null? l) (reverse acc))
              ((memv (car l) acc) (loop (cdr l) acc))
              (else (loop (cdr l) (cons (car l) acc))))))

    (define (filter-map-list f l)
      (let loop ((l l) (acc '()))
        (if (null? l) (reverse acc)
            (let ((v (f (car l)))) (loop (cdr l) (if v (cons v acc) acc))))))

    ;; size in bytes of a ValueRecord, and where its x advance is
    (define (value-size fmt)
      (let loop ((b 0) (n 0))
        (if (= b 8) (* 2 n) (loop (+ b 1) (if (odd? (quotient fmt (expt 2 b))) (+ n 1) n)))))
    (define (x-advance bv rec fmt)
      (if (odd? (quotient fmt 4))
          (s16 bv (+ rec (value-size (modulo fmt 4))))
          0))

    ;; -> procedure (l r) -> adjustment, or #f when this subtable does not
    ;; have the pair
    (define (pair-subtable bv st)
      (let* ((format (u16 bv st))
             (cov (let ((h (make-hash-table eqv?)))
                    (for-each (lambda (p) (hash-table-set! h (car p) (cdr p)))
                              (coverage bv (+ st (u16 bv (+ st 2)))))
                    h))
             (vf1 (u16 bv (+ st 4)))
             (vf2 (u16 bv (+ st 6)))
             (rec-size (+ (value-size vf1) (value-size vf2))))
        (case format
          ((1)
           (lambda (l r)
             (let ((ci (hash-table-ref/default cov l #f)))
               (and ci
                    (let* ((ps (+ st (u16 bv (+ st 10 (* 2 ci)))))
                           (n (u16 bv ps)))
                      ;; pair value records are sorted by the second glyph
                      (let search ((lo 0) (hi (- n 1)))
                        (and (<= lo hi)
                             (let* ((mid (quotient (+ lo hi) 2))
                                    (rec (+ ps 2 (* mid (+ 2 rec-size))))
                                    (g (u16 bv rec)))
                               (cond ((< g r) (search (+ mid 1) hi))
                                     ((> g r) (search lo (- mid 1)))
                                     (else (x-advance bv (+ rec 2) vf1)))))))))))
          ((2)
           (let ((cd1 (class-def bv (+ st (u16 bv (+ st 8)))))
                 (cd2 (class-def bv (+ st (u16 bv (+ st 10)))))
                 (c2n (u16 bv (+ st 14))))
             (lambda (l r)
               (and (hash-table-ref/default cov l #f)
                    (let ((c1 (cd1 l)) (c2 (cd2 r)))
                      (x-advance bv (+ st 16 (* rec-size (+ (* c1 c2n) c2))) vf1))))))
          (else (lambda (l r) #f)))))

    ;; -> procedure gid -> class (0 when not listed)
    (define (class-def bv o)
      (if (= 1 (u16 bv o))
          (let ((start (u16 bv (+ o 2))) (n (u16 bv (+ o 4))))
            (lambda (g)
              (if (and (>= g start) (< g (+ start n)))
                  (u16 bv (+ o 6 (* 2 (- g start))))
                  0)))
          (let ((n (u16 bv (+ o 2))))
            (lambda (g)
              ;; class range records are sorted by start glyph
              (let search ((lo 0) (hi (- n 1)))
                (if (> lo hi)
                    0
                    (let* ((mid (quotient (+ lo hi) 2))
                           (r (+ o 4 (* 6 mid))))
                      (cond ((< g (u16 bv r)) (search lo (- mid 1)))
                            ((> g (u16 bv (+ r 2))) (search (+ mid 1) hi))
                            (else (u16 bv (+ r 4)))))))))))

    ;; --- fonts ----------------------------------------------------------

    (define (read-truetype bv . options)
      "Syntax: (read-truetype bytevector [options])
Library: (scm truetype)
Description: Parses a TrueType font (.ttf) and returns a font. Glyph
  outlines are decoded when first asked for. OpenType fonts with CFF
  outlines (.otf) are not supported. options is an alist; (features
  \"ss07\" \"tnum\" ...) switches on OpenType features, of which the
  single substitutions are applied (stylistic sets, character variants,
  figure styles); kerning stays that of the kern table.
Example:
  (define font (read-truetype (call-with-port
                 (open-binary-input-file \"DejaVuSans.ttf\")
                 (lambda (p) (read-bytevector 1000000 p)))))
  (read-truetype bv '((features \"tnum\")))"
      (let* ((options (if (pair? options) (car options) '()))
             (features (let ((p (assq 'features options))) (if p (cdr p) '())))
             (tables (table-directory bv))
             (head (table tables "head"))
             (hhea (table tables "hhea"))
             (hmtx (table tables "hmtx"))
             (nmetrics (u16 bv (+ hhea 34)))
             (glyf (table tables "glyf"))
             (loca (table tables "loca"))
             (long-loca? (= 1 (s16 bv (+ head 50))))
             (subst (gsub-singles bv tables features))
             (gid-of (let ((cmap (cmap-lookup bv (table tables "cmap"))))
                       (if (= 0 (hash-table-size subst))
                           cmap
                           (lambda (c)
                             (let ((g (cmap c)))
                               (hash-table-ref/default subst g g))))))
             (advance (lambda (gid)
                        (u16 bv (+ hmtx (* 4 (min gid (- nmetrics 1)))))))
             (cache (make-hash-table eqv?))
             (pairs (kern-pairs bv tables))
             (gpos (and (= 0 (hash-table-size pairs)) (gpos-kerning bv tables))))
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
           (let ((l (gid-of (char->integer left))) (r (gid-of (char->integer right))))
             (if gpos
                 (gpos l r)
                 (hash-table-ref/default pairs (cons l r) 0))))
         #f)))

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
                      (hash-table-ref/default k (cons left right) 0))
                    (list-sort-chars (map car glyphs)))))

    (define (list-sort-chars cs)
      ;; Insertion into a sorted list; fonts have a few hundred glyphs.
      (let loop ((cs cs) (out '()))
        (if (null? cs)
            out
            (loop (cdr cs)
                  (let ins ((xs out))
                    (cond ((null? xs) (list (car cs)))
                          ((char<? (car cs) (car xs)) (cons (car cs) xs))
                          ((char=? (car cs) (car xs)) xs)
                          (else (cons (car xs) (ins (cdr xs))))))))))

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


    ;; --- writing TrueType files ---------------------------------------
    ;; font->truetype turns a font made from glyph data back into a .ttf
    ;; file: what a PDF embeds, so that a document shows exactly the
    ;; glyphs (OpenType features applied) of a library font such as
    ;; (scm fonts inter). Glyph 0 is an empty .notdef, then one simple
    ;; glyph per character in code point order, coordinates uncompressed.

    (define (bv-out) (open-output-bytevector))
    (define (w8 p v) (write-u8 (modulo v 256) p))
    (define (w16 p v)
      (let ((v (if (< v 0) (+ v 65536) v)))
        (w8 p (quotient v 256)) (w8 p (remainder v 256))))
    (define (w32 p v)
      (let ((v (if (< v 0) (+ v 4294967296) v)))
        (w16 p (quotient v 65536)) (w16 p (remainder v 65536))))
    (define (w-tag p s) (for-each (lambda (c) (w8 p (char->integer c))) (string->list s)))

    (define (glyph-points contours) (apply append contours))

    (define (ipart x) (exact (round x)))

    (define (glyph-bbox contours)
      (let ((pts (glyph-points contours)))
        (if (null? pts)
            '(0 0 0 0)
            (let loop ((ps pts) (x0 #f) (y0 #f) (x1 #f) (y1 #f))
              (if (null? ps)
                  (list x0 y0 x1 y1)
                  (let ((x (ipart (car (car ps)))) (y (ipart (cadr (car ps)))))
                    (loop (cdr ps)
                          (if x0 (min x0 x) x) (if y0 (min y0 y) y)
                          (if x1 (max x1 x) x) (if y1 (max y1 y) y))))))))

    ;; The glyf entry of a simple glyph, padded to 4 bytes; empty for a
    ;; glyph without contours.
    (define (encode-glyph contours)
      (let ((contours (filter-nonempty contours)))
        (if (null? contours)
            (bytevector)
            (let ((p (bv-out))
                  (bbox (glyph-bbox contours))
                  (pts (glyph-points contours)))
              (w16 p (length contours))
              (for-each (lambda (v) (w16 p v)) bbox)
              (let loop ((cs contours) (end -1))
                (unless (null? cs)
                  (let ((e (+ end (length (car cs)))))
                    (w16 p e)
                    (loop (cdr cs) e))))
              (w16 p 0)                       ; no instructions
              (for-each (lambda (pt) (w8 p (if (caddr pt) 1 0))) pts)
              (let loop ((ps pts) (prev 0))
                (unless (null? ps)
                  (let ((x (ipart (car (car ps)))))
                    (w16 p (- x prev))
                    (loop (cdr ps) x))))
              (let loop ((ps pts) (prev 0))
                (unless (null? ps)
                  (let ((y (ipart (cadr (car ps)))))
                    (w16 p (- y prev))
                    (loop (cdr ps) y))))
              (let loop ()
                (when (not (= 0 (remainder (bytevector-length (get-output-bytevector p)) 4)))
                  (w8 p 0)
                  (loop)))
              (get-output-bytevector p)))))

    (define (filter-nonempty xs)
      (cond ((null? xs) '())
            ((null? (car xs)) (filter-nonempty (cdr xs)))
            (else (cons (car xs) (filter-nonempty (cdr xs))))))

    ;; cmap segments: runs of consecutive code points (whose glyph ids are
    ;; then consecutive too) as (start end gid-of-start).
    (define (cmap-segments cps)
      (let loop ((cps cps) (gid 1) (acc '()))
        (if (null? cps)
            (reverse acc)
            (let run ((end (car cps)) (rest (cdr cps)) (n 1))
              (if (and (pair? rest) (= (car rest) (+ end 1)))
                  (run (car rest) (cdr rest) (+ n 1))
                  (loop rest (+ gid n) (cons (list (car cps) end gid) acc)))))))

    (define (log2-floor n) (let loop ((k 0)) (if (> (expt 2 (+ k 1)) n) k (loop (+ k 1)))))

    (define (cmap-table cps)
      (let* ((segs (cmap-segments cps))
             (bmp (let loop ((ss segs))
                    (cond ((null? ss) '())
                          ((> (cadr (car ss)) #xFFFF) '())
                          (else (cons (car ss) (loop (cdr ss)))))))
             (segs4 (append bmp (list (list #xFFFF #xFFFF 0))))
             (n (length segs4))
             (f4 (let ((p (bv-out)))
                   (w16 p 4) (w16 p (+ 16 (* 8 n))) (w16 p 0)
                   (w16 p (* 2 n))
                   (let ((sr (* 2 (expt 2 (log2-floor n)))))
                     (w16 p sr) (w16 p (log2-floor n)) (w16 p (- (* 2 n) sr)))
                   (for-each (lambda (s) (w16 p (cadr s))) segs4)
                   (w16 p 0)
                   (for-each (lambda (s) (w16 p (car s))) segs4)
                   (for-each (lambda (s)
                               (w16 p (if (= (car s) #xFFFF) 1
                                          (modulo (- (caddr s) (car s)) 65536))))
                             segs4)
                   (for-each (lambda (s) (w16 p 0)) segs4)
                   (get-output-bytevector p)))
             (f12 (let ((p (bv-out)))
                    (w16 p 12) (w16 p 0) (w32 p (+ 16 (* 12 (length segs))))
                    (w32 p 0) (w32 p (length segs))
                    (for-each (lambda (s) (w32 p (car s)) (w32 p (cadr s)) (w32 p (caddr s))) segs)
                    (get-output-bytevector p)))
             (p (bv-out)))
        (w16 p 0) (w16 p 2)
        (w16 p 3) (w16 p 1) (w32 p 20)
        (w16 p 3) (w16 p 10) (w32 p (+ 20 (bytevector-length f4)))
        (write-bytevector f4 p)
        (write-bytevector f12 p)
        (get-output-bytevector p)))

    (define (name-table family style)
      (let* ((full (if (string=? style "Regular") family (string-append family " " style)))
             (ps (string-append (string-remove-spaces family) "-" style))
             (records (list (cons 1 family) (cons 2 style) (cons 3 ps) (cons 4 full) (cons 6 ps)))
             (enc (map (lambda (r) (cons (car r) (utf16be (cdr r)))) records))
             (p (bv-out)))
        (w16 p 0) (w16 p (length enc)) (w16 p (+ 6 (* 12 (length enc))))
        (let loop ((rs enc) (off 0))
          (unless (null? rs)
            (w16 p 3) (w16 p 1) (w16 p #x409) (w16 p (car (car rs)))
            (w16 p (bytevector-length (cdr (car rs)))) (w16 p off)
            (loop (cdr rs) (+ off (bytevector-length (cdr (car rs)))))))
        (for-each (lambda (r) (write-bytevector (cdr r) p)) enc)
        (get-output-bytevector p)))

    (define (string-remove-spaces s)
      (list->string (let loop ((cs (string->list s)))
                      (cond ((null? cs) '())
                            ((char=? (car cs) #\space) (loop (cdr cs)))
                            (else (cons (car cs) (loop (cdr cs))))))))

    (define (utf16be s)
      (let ((p (bv-out)))
        (for-each (lambda (c)
                    (let ((cp (char->integer c)))
                      (if (< cp #x10000)
                          (w16 p cp)
                          (let ((v (- cp #x10000)))
                            (w16 p (+ #xD800 (quotient v 1024)))
                            (w16 p (+ #xDC00 (remainder v 1024)))))))
                  (string->list s))
        (get-output-bytevector p)))

    (define (table-checksum bv)
      (let ((n (bytevector-length bv)))
        (let loop ((i 0) (sum 0))
          (if (>= i n)
              sum
              (let ((b (lambda (k) (if (< (+ i k) n) (bytevector-u8-ref bv (+ i k)) 0))))
                (loop (+ i 4)
                      (modulo (+ sum (* (b 0) 16777216) (* (b 1) 65536) (* (b 2) 256) (b 3))
                              4294967296)))))))

    (define (pad4 bv)
      (let ((r (remainder (bytevector-length bv) 4)))
        (if (= r 0) bv (bytevector-append bv (make-bytevector (- 4 r) 0)))))

    (define (font->truetype font family . style)
      "Syntax: (font->truetype font family [style])
Library: (scm truetype)
Description: Returns a TrueType file (bytevector) with the glyphs of
  font, which must list its characters (fonts made with
  make-outline-font, such as those of (scm fonts inter) and
  (scm fonts dejavu)). family names it; style is \"Regular\" (default),
  \"Bold\", \"Black\" and so on, which also sets the weight. The file
  has no hinting and no kerning table: a PDF positions the glyphs
  itself.
Example:
  (pdf-embed-truetype-font doc (font->truetype inter-regular \"Inter\") \"Inter\")"
      (let* ((style (if (pair? style) (car style) "Regular"))
             (chars (or (font-chars font)
                        (error "font->truetype: the font does not list its characters")))
             (upem (font-units-per-em font))
             (glyphs (cons (cons (quotient upem 2) '())    ; .notdef
                           (map (lambda (c) (font-glyph font c)) chars)))
             (encoded (map (lambda (g) (encode-glyph (cdr g))) glyphs))
             (bboxes (map (lambda (g) (glyph-bbox (filter-nonempty (cdr g)))) glyphs))
             (num (length glyphs))
             (glyf (apply bytevector-append encoded))
             (loca (let ((p (bv-out)))
                     (let loop ((es encoded) (off 0))
                       (w32 p off)
                       (unless (null? es)
                         (loop (cdr es) (+ off (bytevector-length (car es))))))
                     (get-output-bytevector p)))
             (advances (map car glyphs))
             (inked (let loop ((gs glyphs) (bs bboxes) (acc '()))
                      (cond ((null? gs) acc)
                            ((null? (filter-nonempty (cdr (car gs)))) (loop (cdr gs) (cdr bs) acc))
                            (else (loop (cdr gs) (cdr bs) (cons (car bs) acc))))))
             (x-min (apply min 0 (map car inked)))
             (y-min (apply min 0 (map cadr inked)))
             (x-max (apply max 0 (map caddr inked)))
             (y-max (apply max 0 (map cadddr inked)))
             (hmtx (let ((p (bv-out)))
                     (for-each (lambda (a b) (w16 p (ipart a)) (w16 p (car b))) advances bboxes)
                     (get-output-bytevector p)))
             (max-points (apply max 0 (map (lambda (g) (length (glyph-points (cdr g)))) glyphs)))
             (max-contours (apply max 0 (map (lambda (g) (length (filter-nonempty (cdr g)))) glyphs)))
             (weight (cond ((member style '("Black" "Heavy")) 900)
                           ((member style '("Bold")) 700)
                           ((member style '("Light")) 300)
                           (else 400)))
             (bold? (>= weight 700))
             (ascent (font-ascent font))
             (descent (font-descent font))
             (yof (lambda (c) (let ((g (font-glyph font c)))
                                (if g (cadddr (glyph-bbox (filter-nonempty (cdr g)))) 0))))
             (head (let ((p (bv-out)))
                     (w32 p #x00010000) (w32 p #x00010000) (w32 p 0) (w32 p #x5F0F3CF5)
                     (w16 p #x000B) (w16 p upem)
                     (w32 p 0) (w32 p 0) (w32 p 0) (w32 p 0)
                     (w16 p x-min) (w16 p y-min) (w16 p x-max) (w16 p y-max)
                     (w16 p (if bold? 1 0)) (w16 p 8) (w16 p 2) (w16 p 1) (w16 p 0)
                     (get-output-bytevector p)))
             (hhea (let ((p (bv-out)))
                     (w32 p #x00010000) (w16 p ascent) (w16 p descent) (w16 p 0)
                     (w16 p (ipart (apply max advances))) (w16 p x-min) (w16 p 0) (w16 p x-max)
                     (w16 p 1) (w16 p 0) (w16 p 0)
                     (w16 p 0) (w16 p 0) (w16 p 0) (w16 p 0) (w16 p 0) (w16 p num)
                     (get-output-bytevector p)))
             (maxp (let ((p (bv-out)))
                     (w32 p #x00010000) (w16 p num) (w16 p max-points) (w16 p max-contours)
                     (w16 p 0) (w16 p 0) (w16 p 2)
                     (do ((i 0 (+ i 1))) ((= i 8)) (w16 p 0))
                     (get-output-bytevector p)))
             (os2 (let ((p (bv-out))
                        (cps (map char->integer chars)))
                    (w16 p 4)
                    (w16 p (ipart (/ (apply + advances) num)))
                    (w16 p weight) (w16 p 5) (w16 p 0)
                    (w16 p (quotient upem 2)) (w16 p (quotient upem 2)) (w16 p 0) (w16 p (quotient upem 10))
                    (w16 p (quotient upem 2)) (w16 p (quotient upem 2)) (w16 p 0) (w16 p (quotient upem 3))
                    (w16 p (quotient upem 20)) (w16 p (quotient upem 4))
                    (w16 p 0)
                    (do ((i 0 (+ i 1))) ((= i 10)) (w8 p 0))
                    (w32 p 3) (w32 p 0) (w32 p 0) (w32 p 0)
                    (w-tag p "NONE")
                    (w16 p (if bold? #x20 #x40))
                    (w16 p (min #xFFFF (apply min cps))) (w16 p (min #xFFFF (apply max cps)))
                    (w16 p ascent) (w16 p descent) (w16 p 0)
                    (w16 p ascent) (w16 p (- descent))
                    (w32 p 1) (w32 p 0)
                    (w16 p (yof #\x)) (w16 p (yof #\H))
                    (w16 p 0) (w16 p 32) (w16 p 0)
                    (get-output-bytevector p)))
             (post (let ((p (bv-out)))
                     (w32 p #x00030000) (w32 p 0) (w16 p (- (quotient upem 10))) (w16 p (quotient upem 20))
                     (do ((i 0 (+ i 1))) ((= i 5)) (w32 p 0))
                     (get-output-bytevector p)))
             (tables (list (cons "OS/2" os2) (cons "cmap" (cmap-table (map char->integer chars)))
                           (cons "glyf" glyf) (cons "head" head) (cons "hhea" hhea)
                           (cons "hmtx" hmtx) (cons "loca" loca) (cons "maxp" maxp)
                           (cons "name" (name-table family style)) (cons "post" post)))
             (n (length tables))
             (dir-len (+ 12 (* 16 n)))
             (out (bv-out)))
        (w32 out #x00010000) (w16 out n)
        (let ((sr (* 16 (expt 2 (log2-floor n)))))
          (w16 out sr) (w16 out (log2-floor n)) (w16 out (- (* 16 n) sr)))
        (let loop ((ts tables) (off dir-len))
          (unless (null? ts)
            (let ((data (cdr (car ts))))
              (w-tag out (car (car ts)))
              (w32 out (table-checksum data))
              (w32 out off)
              (w32 out (bytevector-length data))
              (loop (cdr ts) (+ off (bytevector-length (pad4 data)))))))
        (for-each (lambda (t) (write-bytevector (pad4 (cdr t)) out)) tables)
        (let* ((bv (get-output-bytevector out))
               (head-off (let loop ((ts tables) (off dir-len))
                           (if (string=? (car (car ts)) "head")
                               off
                               (loop (cdr ts) (+ off (bytevector-length (pad4 (cdr (car ts))))))))))
          (bytevector-u32-set! bv (+ head-off 8)
                               (modulo (- #xB1B0AFBA (table-checksum bv)) 4294967296) 'big)
          bv)))

))
