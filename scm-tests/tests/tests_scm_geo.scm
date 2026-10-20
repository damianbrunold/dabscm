(import (scheme base)
        (scheme inexact)
        (srfi 1)
        (scm test)
        (scm bytevector)
        (scm json simple)
        (scm geo)
        (scm geo shapefile)
        (scm geo topology)
        (scm geo topojson))

(test-runner-factory scm-test-runner)

(test-begin "scm geo")

(define (box x y s) (vector x y (+ x s) y (+ x s) (+ y s) x (+ y s) x y))
(define (feature name . rings) (make-feature (list (cons "name" name)) (make-polygon rings)))
(define (names g f) (map (lambda (x) (feature-ref x "name")) (planar-graph-face-features g f)))
(define (sorted-areas parts)
  (map (lambda (p) (cons (car p) (rings-area (cdr p))))
       (sort-parts parts)))
(define (sort-parts parts)
  (fold (lambda (p acc)
          (let ins ((acc acc))
            (cond ((null? acc) (list p))
                  ((string<? (car p) (caar acc)) (cons p acc))
                  (else (cons (car acc) (ins (cdr acc)))))))
        '() parts))

(test-group "rings"
  (test-equal 4.0 (ring-area (box 0 0 2)))
  (test-equal -4.0 (ring-area (ring-reverse (box 0 0 2))))
  (test-equal #(0 0 2 2) (ring-bbox (box 0 0 2)))
  (test-equal #(0 -1 3 1) (bbox-union #(0 0 1 1) #(2 -1 3 0)))
  (test-assert (bbox-overlap? #(0 0 1 1) #(1 1 2 2)))
  (test-assert (not (bbox-overlap? #(0 0 1 1) #(1.5 0 2 1))))
  (test-assert (point-in-ring? 1 1 (box 0 0 2)))
  (test-assert (not (point-in-ring? 3 1 (box 0 0 2))))
  (test-assert (not (point-in-rings? 1.5 1.5 (list (box 0 0 4) (box 1 1 1)))))
  (test-equal 15.0 (rings-area (list (box 0 0 4) (box 1 1 1)))))

(test-group "polygons"
  ;; a hole the wrong way round, and a second polygon
  (let ((ps (rings->polygons (list (ring-reverse (box 0 0 4)) (box 1 1 1) (box 10 0 1)))))
    (test-equal 2 (length ps))
    (test-equal 16.0 (ring-area (car (car ps))))
    (test-equal -1.0 (ring-area (cadr (car ps))))
    (test-equal 1 (length (cadr ps))))
  (test-equal '(((0 . #f) (1 . #t))) (ring-groups (list (box 0 0 4) (box 1 1 1)))))

(test-group "simplification"
  (test-equal #(-1 1 -1) (path-dp-thresholds #(0 0 1 1 2 0)))
  (test-equal #(0 0 2 0) (path-simplify #(0 0 1 0.1 2 0) 0.5))
  (test-equal #(0 0 1 0.1 2 0) (path-simplify #(0 0 1 0.1 2 0) 0.05))
  ;; a closed path keeps its start and the point farthest from it
  (let ((w (path-dp-thresholds (box 0 0 2))))
    (test-equal -1 (vector-ref w 0))
    (test-equal -1 (vector-ref w 2))
    (test-equal -1 (vector-ref w 4))))

(test-group "inner point"
  (let ((p (polygon-inner-point (list (box 0 0 4)) 0.01)))
    (test-assert (< (abs (- (vector-ref p 0) 2)) 0.02))
    (test-assert (< (abs (- (vector-ref p 1) 2)) 0.02)))
  ;; a U shape: the point must not fall into the notch
  (let ((p (polygon-inner-point (list #(0 0 3 0 3 3 2 3 2 1 1 1 1 3 0 3 0 0)) 0.01)))
    (test-assert (point-in-ring? (vector-ref p 0) (vector-ref p 1) #(0 0 3 0 3 3 2 3 2 1 1 1 1 3 0 3 0 0)))))

(test-group "geojson"
  (let* ((fs (list (feature "A" (box 0 0 4) (box 1 1 1))
                   (make-feature '(("id" . 7)) (make-polyline (list #(0 0 5 5))))))
         (j (json-parse (json->string (features->geojson fs))))
         (back (geojson->features j)))
    (test-equal "FeatureCollection" (json-ref j "type"))
    (test-equal 2 (length back))
    (test-equal 15 (exact (rings-area (feature-rings (car back)))))
    (test-equal 7 (feature-ref (cadr back) "id"))
    (test-equal 'polyline (geometry-type (feature-geometry (cadr back))))))

;; --- shapefiles, built by hand ----------------------------------------

(define (make-shp ring)
  (let* ((np (ring-point-count ring))
         (content (+ 44 4 (* 16 np)))
         (bv (make-bytevector (+ 100 8 content) 0)))
    (bytevector-u32-set! bv 0 9994 'big)
    (bytevector-u32-set! bv 24 (quotient (bytevector-length bv) 2) 'big)
    (bytevector-u32-set! bv 28 1000 'little)
    (bytevector-u32-set! bv 32 5 'little)
    (bytevector-u32-set! bv 100 1 'big)
    (bytevector-u32-set! bv 104 (quotient content 2) 'big)
    (bytevector-u32-set! bv 108 5 'little)
    (bytevector-u32-set! bv 144 1 'little)
    (bytevector-u32-set! bv 148 np 'little)
    (bytevector-u32-set! bv 152 0 'little)
    (do ((i 0 (+ i 1))) ((= i np) bv)
      (bytevector-ieee-double-set! bv (+ 156 (* 16 i)) (inexact (vector-ref ring (* 2 i))) 'little)
      (bytevector-ieee-double-set! bv (+ 164 (* 16 i)) (inexact (vector-ref ring (+ 1 (* 2 i)))) 'little))))

(define (make-dbf name number)
  ;; fields NAME C(10), NUM N(5), DAY D(8)
  (let* ((bv (make-bytevector (+ 129 24 1) 32))
         (put-string! (lambda (o s) (bytevector-copy! bv o (string->utf8 s)))))
    (bytevector-u8-set! bv 0 3)
    (bytevector-u32-set! bv 4 1 'little)
    (bytevector-u16-set! bv 8 129 'little)
    (bytevector-u16-set! bv 10 24 'little)
    (for-each (lambda (o field type len)
                (bytevector-copy! bv o (make-bytevector 32 0))
                (put-string! o field)
                (bytevector-u8-set! bv (+ o 11) (char->integer type))
                (bytevector-u8-set! bv (+ o 16) len))
              '(32 64 96) '("NAME" "NUM" "DAY") '(#\C #\N #\D) '(10 5 8))
    (bytevector-u8-set! bv 128 13)
    (put-string! 130 name)
    (put-string! 140 number)
    (put-string! 145 "20260101")
    (bytevector-u8-set! bv 153 26)
    bv))

(test-group "shapefile"
  (let ((fs (shapefile->features (make-shp (ring-reverse (box 0 0 2))) (make-dbf "Zürich" "   42") 'utf-8)))
    (test-equal 1 (length fs))
    (test-equal "Zürich" (feature-ref (car fs) "NAME"))
    (test-equal 42 (feature-ref (car fs) "NUM"))
    (test-equal "2026-01-01" (feature-ref (car fs) "DAY"))
    (test-equal 'polygon (geometry-type (feature-geometry (car fs))))
    (test-equal -4.0 (ring-area (car (feature-rings (car fs))))))
  (test-equal '((("NAME" . "Gen\xe8;ve") ("NUM" . null) ("DAY" . "2026-01-01")))
              (let ((bv (make-dbf "Gen?ve" "     ")))
                (bytevector-u8-set! bv 133 #xE8)
                (dbf->records bv 'latin-1)))
  (test-error (shapefile->features (make-bytevector 100 0) #f)))

;; --- planar graphs ---------------------------------------------------

(test-group "overlay"
  (let ((g (make-planar-graph (list (list (feature "A" (box 0 0 2)))
                                    (list (feature "B" (box 1 1 2)))))))
    (test-equal 4 (planar-graph-face-count g))
    (test-equal '() (names g 0))
    (test-equal '(("A") ("B") ("A" "B"))
                (map (lambda (f) (names g f)) '(1 2 3)))
    (test-equal '(3.0 3.0 1.0) (map (lambda (f) (planar-graph-face-area g f)) '(1 2 3)))
    (let ((all (planar-graph-dissolve g (lambda (f) (and (pair? (names g f)) 'all)))))
      (test-equal 1 (length all))
      (test-equal 7.0 (rings-area (cdar all))))))

(test-group "holes, islands, touching borders"
  ;; A with a hole holding the island C; B next to A, given clockwise; T
  ;; inside B against the border
  (let* ((g (make-planar-graph
             (list (list (feature "A" (ring-reverse (box 0 0 4)) (box 1 1 1))
                         (feature "B" (ring-reverse (box 4 0 4)))
                         (feature "C" (ring-reverse (box 1.25 1.25 0.5)))
                         (feature "T" #(4 1 4 2 4.5 1.5 4 1))))))
         (parts (planar-graph-dissolve g (lambda (f) (let ((n (names g f))) (and (pair? n) (car n)))))))
    (test-equal 6 (planar-graph-face-count g))
    (test-equal '(("A" . 15.0) ("B" . 16.0) ("C" . 0.25)) (sorted-areas parts))
    ;; the hole between A and C is a face covered by nothing
    (test-assert (any (lambda (f) (and (null? (names g f)) (> (planar-graph-face-area g f) 0)))
                      (iota (planar-graph-face-count g))))
    (test-equal '(("all" . 31.25))
                (sorted-areas (planar-graph-dissolve g (lambda (f) (and (pair? (names g f)) "all")))))))

(test-group "vertex on an edge"
  ;; B's corners lie on A's right edge, not on any vertex of A
  (let* ((g (make-planar-graph (list (list (feature "A" (box 0 0 2))
                                           (feature "B" #(2 0.5 3 0.5 3 1.5 2 1.5 2 0.5))))))
         (all (planar-graph-dissolve g (lambda (f) (and (pair? (names g f)) "all")))))
    (test-equal 3 (planar-graph-face-count g))
    (test-equal 1 (length (cdar all)))
    (test-equal 5.0 (ring-area (cadar all)))))

(test-group "snapping"
  ;; B is off A by a millimetre: without snapping they stay apart, with
  ;; snapping they share their border
  (let* ((a (feature "A" (box 0 0 1)))
         (b (feature "B" #(1.001 0 2 0 2 1 1.001 1 1.001 0)))
         (outline (lambda (options)
                    (let ((g (make-planar-graph (list (list a b)) options)))
                      (cdar (planar-graph-dissolve g (lambda (f) (and (pair? (names g f)) "all"))))))))
    (test-equal 2 (length (outline '())))
    (test-equal 1 (length (outline '((snap . 0.01)))))))

(test-group "merging faces"
  ;; a gap between A and B, longer along B: it goes to B
  (let* ((g (make-planar-graph (list (list (feature "A" (box 0 0 4))
                                           (feature "B" #(4 0 8 0 8 4 4 4 4 3 5 3 5 1 4 1 4 0))))))
         (keys (list->vector (map (lambda (f) (let ((n (names g f))) (and (pair? n) (car n))))
                                  (iota (planar-graph-face-count g)))))
         (gap (find (lambda (f) (and (> f 0) (null? (names g f)))) (iota (planar-graph-face-count g)))))
    (test-assert gap)
    (test-equal 2.0 (planar-graph-face-area g gap))
    (test-equal 6.0 (fold + 0 (map cdr (planar-graph-face-neighbours g gap))))
    (planar-graph-merge-faces! g keys (lambda (f) (eqv? f gap)))
    (test-equal "B" (vector-ref keys gap))
    (test-equal '(("A" . 16.0) ("B" . 16.0)) (sorted-areas (planar-graph-dissolve g keys)))))

;; A in two parts, one of them touching B: the parts of A stay apart though
;; they have the same key
(test-group "components"
  (let* ((g (make-planar-graph (list (list (feature "A" (box 0 0 1) (box 5 0 1))
                                           (feature "B" (box 1 0 1))))))
         (keys (list->vector (map (lambda (f) (let ((n (names g f))) (and (pair? n) (car n))))
                                  (iota (planar-graph-face-count g)))))
         (parts (planar-graph-components g keys))
         (as (filter (lambda (f) (equal? (vector-ref keys f) "A")) (iota (planar-graph-face-count g)))))
    (test-equal -1 (vector-ref parts 0))
    (test-equal 3 (length (delete-duplicates (filter (lambda (c) (>= c 0)) (vector->list parts)))))
    (test-equal 2 (length as))
    (test-assert (not (= (vector-ref parts (car as)) (vector-ref parts (cadr as)))))))

;; --- topojson ----------------------------------------------------------

(test-group "topojson"
  (let* ((fs (list (feature "A" (box 0 0 4) (ring-reverse (box 1 1 1)))
                   (feature "B" (box 4 0 4))
                   (feature "I" (box 10 10 1))))
         (t (json-parse (json->string (features->topojson (list (cons "parts" fs))))))
         (arcs (json-ref t "arcs"))
         (geoms (json-ref (json-ref (json-ref t "objects") "parts") "geometries")))
    (test-equal "Topology" (json-ref t "type"))
    ;; the border between A and B is one shared arc
    (test-equal 5 (vector-length arcs))
    (test-equal '("A" "B" "I") (map (lambda (g) (json-ref (json-ref g "properties") "name")) (vector->list geoms)))
    (let ((a (json-ref (vector-ref geoms 0) "arcs"))
          (b (json-ref (vector-ref geoms 1) "arcs")))
      (test-equal 2 (vector-length a))
      (test-assert (any (lambda (i) (any (lambda (j) (= i (- -1 j))) (vector->list (vector-ref b 0))))
                        (vector->list (vector-ref a 0))))))
  (let* ((t (features->topojson (list (cons "x" (list (feature "A" (box 0 0 10)))))
                                '((quantization . 11) (thresholds . "dp") (threshold-scale . 10))))
         (tr (cdr (assoc "transform" t))))
    (test-equal #(1.0 1.0) (cdr (assoc "scale" tr)))
    (test-equal #(#(#(0 0) #(10 0) #(0 10) #(-10 0) #(0 -10))) (cdr (assoc "arcs" t)))
    ;; the ring is counter-clockwise: TopoJSON wants it reversed
    (test-equal #(#(-1)) (cdr (assoc "arcs" (vector-ref (cdr (assoc "geometries" (cdr (assoc "x" (cdr (assoc "objects" t)))))) 0))))
    (test-equal #(#(-1 71 -1 71 -1)) (cdr (assoc "dp" t))))
  ;; simplified away entirely, a ring keeps enough points to stay a polygon
  (let* ((t (features->topojson (list (cons "x" (list (feature "A" (box 0 0 1))
                                                      (feature "B" (box 1 0 1)))))
                                '((simplify . 100))))
         (arcs (vector->list (cdr (assoc "arcs" t)))))
    (test-assert (>= (fold + 0 (map vector-length arcs)) 6))))

(test-end "scm geo")
