(import (scheme base)
        (srfi 1)
        (scm test)
        (scm raster)
        (scm truetype)
        (scm fonts dejavu)
        (scm fonts inter))

(test-runner-factory scm-test-runner)

(test-begin "scm truetype")

;; --- a minimal TrueType font, built byte by byte ---------------------------
;;
;; 1000 units per em. "A" is a square (glyph 1), "B" a composite of the
;; square at half size moved right by 50 (glyph 2), and the pair A B
;; kerns by -50.

(define (u16 n) (let ((n (modulo n 65536))) (list (quotient n 256) (modulo n 256))))
(define (u32 n) (append (u16 (quotient n 65536)) (u16 (modulo n 65536))))
(define (pad bytes) (if (odd? (length bytes)) (append bytes '(0)) bytes))

(define head
  (append (u32 #x10000) (u32 0) (u32 0) (u32 #x5F0F3CF5) (u16 0)
          (u16 1000)                            ; unitsPerEm at 18
          (make-list 16 0)                      ; created, modified
          (u16 0) (u16 0) (u16 600) (u16 700)   ; bbox
          (u16 0) (u16 8) (u16 2)
          (u16 0)                               ; indexToLocFormat at 50: short
          (u16 0)))

(define hhea
  (append (u32 #x10000) (u16 800) (u16 -200) (u16 0) (u16 700)
          (make-list 22 0)
          (u16 3)))                             ; numberOfHMetrics at 34

(define hmtx (append (u16 500) (u16 0) (u16 600) (u16 100) (u16 700) (u16 100)))

(define cmap
  (append (u16 0) (u16 1) (u16 3) (u16 1) (u32 12)
          ;; format 4: 'A'..'B' -> 1..2, and the closing segment
          (u16 4) (u16 32) (u16 0) (u16 4) (u16 4) (u16 1) (u16 0)
          (u16 66) (u16 #xFFFF) (u16 0)
          (u16 65) (u16 #xFFFF)
          (u16 (- 1 65)) (u16 1)
          (u16 0) (u16 0)))

(define square-glyph
  (append (u16 1) (u16 100) (u16 0) (u16 500) (u16 700)
          (u16 3) (u16 0)                       ; end point, no instructions
          '(1 1 1 1)                            ; on curve, 16-bit deltas
          (u16 100) (u16 400) (u16 0) (u16 -400)
          (u16 0) (u16 0) (u16 700) (u16 0)))

(define composite
  (append (u16 -1) (u16 100) (u16 0) (u16 300) (u16 350)
          (u16 (+ 1 2 8))                       ; words, x/y offsets, a scale
          (u16 1) (u16 50) (u16 0) (u16 8192))) ; glyph 1, dx 50, dy 0, 0.5

(define glyf (append (pad square-glyph) (pad composite)))

(define loca
  (append (u16 0) (u16 0)                       ; glyph 0 is empty
          (u16 (/ (length (pad square-glyph)) 2))
          (u16 (/ (length glyf) 2))))

(define kern
  (append (u16 0) (u16 1)
          (u16 0) (u16 20) (u16 1)              ; horizontal, format 0
          (u16 1) (u16 6) (u16 0) (u16 0)
          (u16 1) (u16 2) (u16 -50)))

(define (sfnt tables)
  (let* ((n (length tables))
         (dir-size (+ 12 (* 16 n))))
    (let loop ((ts tables) (offset dir-size) (records '()) (data '()))
      (if (null? ts)
          (apply bytevector
                 (append (u32 #x10000) (u16 n) (u16 0) (u16 0) (u16 0)
                         (reverse records) data))
          (let* ((tag (map char->integer (string->list (caar ts))))
                 (bytes (pad (cdar ts))))
            (loop (cdr ts) (+ offset (length bytes))
                  (append (reverse (append tag (u32 0) (u32 offset) (u32 (length (cdar ts)))))
                          records)
                  (append data bytes)))))))

(define font
  (read-truetype (sfnt (list (cons "head" head) (cons "hhea" hhea) (cons "hmtx" hmtx)
                             (cons "cmap" cmap) (cons "loca" loca) (cons "glyf" glyf)
                             (cons "kern" kern)))))

(test-group "read-truetype"
  (test-assert (font? font))
  (test-equal 1000 (font-units-per-em font))
  (test-equal 800 (font-ascent font))
  (test-equal -200 (font-descent font))
  (test-equal '(600 ((100 0 #t) (500 0 #t) (500 700 #t) (100 700 #t)))
              (font-glyph font #\A))
  ;; the composite: the square scaled by 0.5 and moved by 50
  (let ((g (font-glyph font #\B)))
    (test-equal 700 (car g))
    (test-equal '((100 0 #t) (300 0 #t) (300 350 #t) (100 350 #t))
                (map (lambda (p) (list (exact (round (car p))) (exact (round (cadr p))) (caddr p)))
                     (cadr g))))
  (test-equal #f (font-glyph font #\C))
  (test-equal -50 (font-kerning font #\A #\B))
  (test-equal 0 (font-kerning font #\B #\A)))

;; GSUB: feature ss01 replaces glyph 1 (A) by glyph 2 (B), a format 1
;; single substitution (delta +1).
(define gsub
  (append (u16 1) (u16 0) (u16 10) (u16 12) (u16 26)
          (u16 0)                                       ; no scripts
          (u16 1) (map char->integer (string->list "ss01")) (u16 8)
          (u16 0) (u16 1) (u16 0)                       ; feature: lookup 0
          (u16 1) (u16 4)                               ; lookup list
          (u16 1) (u16 0) (u16 1) (u16 8)               ; type 1, one subtable
          (u16 1) (u16 6) (u16 1)                       ; format 1, delta +1
          (u16 1) (u16 1) (u16 1)))                     ; coverage: glyph 1

;; GPOS kern: A B -30 in a format 1 subtable; B A -40 in a format 2
;; (class) subtable after it.
(define gpos
  (append (u16 1) (u16 0) (u16 10) (u16 12) (u16 26)
          (u16 0)
          (u16 1) (map char->integer (string->list "kern")) (u16 8)
          (u16 0) (u16 1) (u16 0)
          (u16 1) (u16 4)
          (u16 2) (u16 0) (u16 2) (u16 10) (u16 34)     ; type 2, two subtables
          ;; format 1: first glyphs {1}, pair set {2: -30}
          (u16 1) (u16 18) (u16 4) (u16 0) (u16 1) (u16 12)
          (u16 1) (u16 2) (u16 -30)
          (u16 1) (u16 1) (u16 1)
          ;; format 2: first glyphs {2}, class 1 of the first is glyph 2,
          ;; class 1 of the second glyph 1
          (u16 2) (u16 24) (u16 4) (u16 0) (u16 30) (u16 38) (u16 2) (u16 2)
          (u16 0) (u16 0) (u16 0) (u16 -40)
          (u16 1) (u16 1) (u16 2)
          (u16 1) (u16 2) (u16 1) (u16 1)
          (u16 2) (u16 1) (u16 1) (u16 1) (u16 1)))

(define (font-with . extra)
  (sfnt (append (list (cons "head" head) (cons "hhea" hhea) (cons "hmtx" hmtx)
                      (cons "cmap" cmap) (cons "loca" loca) (cons "glyf" glyf))
                extra)))

(test-group "OpenType features"
  (let ((bv (font-with (cons "GSUB" gsub))))
    (test-equal 600 (car (font-glyph (read-truetype bv) #\A)))
    ;; with ss01, A is drawn with glyph 2
    (test-equal 700 (car (font-glyph (read-truetype bv '((features "ss01"))) #\A)))
    (test-equal 600 (car (font-glyph (read-truetype bv '((features "ss02"))) #\A)))))

(test-group "GPOS kerning"
  (let ((f (read-truetype (font-with (cons "GPOS" gpos)))))
    (test-equal -30 (font-kerning f #\A #\B))
    (test-equal -40 (font-kerning f #\B #\A))
    (test-equal 0 (font-kerning f #\A #\A))
    (test-equal 0 (font-kerning f #\B #\B))))

(test-group "text"
  ;; at 1000 px per em, one unit is one pixel
  (test-approximate 1250.0 (font-text-width font 1000 "AB") 1e-9)
  (test-approximate 12.5 (font-text-width font 10 "AB") 1e-9)
  ;; y flips: the baseline is at y, glyphs go up from it
  (let ((p (font-text-path font 1000 10 800 "A")))
    (test-equal '(M 110.0 800.0) (car p))
    (test-equal '(L 510.0 800.0) (cadr p))
    (test-equal '(L 510.0 100.0) (caddr p))
    (test-equal '(Z) (last p)))
  ;; characters the font lacks are left out when there is no "?"
  (test-equal '() (font-text-path font 10 0 0 "C")))

(test-group "make-outline-font"
  ;; a contour with an off-curve point between two on-curve ones, and
  ;; two off-curve points in a row (an implied on-curve point between)
  (let* ((f (make-outline-font 100 80 -20
                               (list (list #\a 50 '((0 0 #t) (50 50 #f) (100 0 #t)))
                                     (list #\b 60 '((0 0 #t) (0 50 #f) (50 50 #f) (50 0 #t)))
                                     (list #\? 40 '()))
                               '(((#\a . #\b) . -5))))
         (pa (font-text-path f 100 0 0 "a"))
         (pb (font-text-path f 100 0 0 "b")))
    (test-equal '(M 0.0 0.0) (car pa))
    (test-equal '(Q 50.0 -50.0 100.0 0.0) (cadr pa))
    (test-equal '(Q 0.0 -50.0 25.0 -50.0) (cadr pb))
    (test-equal '(Q 50.0 -50.0 50.0 0.0) (caddr pb))
    (test-equal -5 (font-kerning f #\a #\b))
    (test-approximate 105.0 (font-text-width f 100 "ab") 1e-9)
    ;; a missing character is set as "?"
    (test-approximate 40.0 (font-text-width f 100 "z") 1e-9)))

(test-group "dejavu"
  (test-equal 2048 (font-units-per-em dejavu-sans))
  (test-equal 1401 (car (font-glyph dejavu-sans #\A)))
  (test-assert (pair? (cdr (font-glyph dejavu-sans (integer->char #xE4)))))   ; ä
  (test-assert (font-glyph dejavu-sans-bold (integer->char #x2019)))          ; ’
  (test-assert (< (font-kerning dejavu-sans #\A #\V) 0))
  ;; NO₂, m³
  (test-assert (pair? (cdr (font-glyph dejavu-sans (integer->char #x2082)))))
  (test-assert (pair? (cdr (font-glyph inter-black (integer->char #x2082)))))
  (test-assert (pair? (cdr (font-glyph inter-regular (integer->char #xB3)))))
  (test-assert (> (font-text-width dejavu-sans-bold 12 "Intern")
                  (font-text-width dejavu-sans 12 "Intern")))
  ;; it draws
  (let ((c (make-canvas 60 20 (rgba 255 255 255))))
    (canvas-fill-path! c (font-text-path dejavu-sans 14 2 15 "Zürich") (rgba 0 0 0))
    (test-assert (let loop ((x 0) (y 0))
                   (cond ((= y 20) #f)
                         ((= x 60) (loop 0 (+ y 1)))
                         ((< (car (canvas-ref c x y)) 50) #t)
                         (else (loop (+ x 1) y)))))))

(test-group "inter"
  (test-equal 2048 (font-units-per-em inter-regular))
  ;; tabular figures: every digit as wide as every other
  (test-approximate (font-text-width inter-regular 12 "8888")
                    (font-text-width inter-regular 12 "1111") 1e-9)
  (test-assert (< (font-kerning inter-regular #\T #\o) 0))
  (test-assert (> (font-text-width inter-black 12 "Intern")
                  (font-text-width inter-regular 12 "Intern"))))

(test-group "font->truetype"
  (test-equal 257 (length (font-chars inter-regular)))
  (test-assert (char<? (car (font-chars inter-regular)) (cadr (font-chars inter-regular))))
  (test-equal #f (font-chars (read-truetype (font->truetype dejavu-sans "DejaVu Sans"))))
  ;; A file with the same glyphs: read back, every glyph is the same.
  (let* ((ttf (font->truetype inter-black "Inter" "Black"))
         (back (read-truetype ttf)))
    (test-equal (bytevector #x00 #x01 #x00 #x00) (bytevector-copy ttf 0 4))
    (test-assert "all glyphs survive"
      (every (lambda (c) (equal? (font-glyph back c) (font-glyph inter-black c)))
             (font-chars inter-black)))
    (test-equal (font-units-per-em inter-black) (font-units-per-em back))
    (test-equal (font-ascent inter-black) (font-ascent back))
    (test-equal #f (font-glyph back #\x4E00)))
  (test-error (font->truetype (read-truetype (font->truetype inter-regular "Inter")) "X")))

(test-end "scm truetype")
