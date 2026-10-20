(define-library (scm geo)
  (import (scheme base)
          (scheme inexact)
          (srfi 1))
  (export make-feature
          feature?
          feature-properties
          feature-geometry
          feature-ref
          make-polygon
          make-polyline
          make-multipoint
          geometry-type
          geometry-parts
          feature-rings
          ring-point-count
          ring-area
          rings-area
          ring-bbox
          rings-bbox
          bbox-union
          bbox-overlap?
          ring-reverse
          point-in-ring?
          point-in-rings?
          rings->polygons
          ring-groups
          path-dp-thresholds
          path-simplify
          polygon-inner-point
          features->geojson
          geojson->features)
  (begin

    ;; --- features and geometries -----------------------------------

    (define-record-type feature
      (make-feature properties geometry)
      feature?
      (properties feature-properties)
      (geometry feature-geometry))

    (define (feature-ref f key . default)
      "Syntax: (feature-ref feature key [default])
Library: (scm geo)
Description: Returns the value of the property named key (a string) of feature,
  or default (#f when omitted) when the feature has no such property. A
  property that is present but empty holds the symbol null.
Example:
  (feature-ref (make-feature '((\"name\" . \"Bern\")) (make-polygon '())) \"name\") => \"Bern\""
      (let ((p (assoc key (feature-properties f))))
        (if p (cdr p) (if (pair? default) (car default) #f))))

    ;; A geometry is a tagged list: (polygon ring ...), (polyline path ...)
    ;; or (multipoint point ...). A ring or path is a flat vector of
    ;; coordinates #(x0 y0 x1 y1 ...); a ring is closed, its last point equal
    ;; to its first. A point is #(x y).
    (define (make-polygon rings)
      "Syntax: (make-polygon rings)
Library: (scm geo)
Description: Returns a polygon geometry made of rings, a list of closed rings,
  each a flat vector #(x0 y0 x1 y1 ... x0 y0). Outer rings and holes may come
  in any order; the area inside an odd number of rings is the polygon.
Example:
  (geometry-type (make-polygon (list #(0 0 1 0 1 1 0 0)))) => polygon"
      (cons 'polygon rings))

    (define (make-polyline paths)
      "Syntax: (make-polyline paths)
Library: (scm geo)
Description: Returns a polyline geometry made of paths, a list of flat
  coordinate vectors #(x0 y0 x1 y1 ...).
Example:
  (geometry-parts (make-polyline (list #(0 0 5 5)))) => (#(0 0 5 5))"
      (cons 'polyline paths))

    (define (make-multipoint points)
      "Syntax: (make-multipoint points)
Library: (scm geo)
Description: Returns a point geometry made of points, a list of vectors #(x y).
Example:
  (geometry-type (make-multipoint (list #(1 2)))) => multipoint"
      (cons 'multipoint points))

    (define (geometry-type g)
      "Syntax: (geometry-type geometry)
Library: (scm geo)
Description: Returns the type of geometry: one of the symbols polygon,
  polyline or multipoint.
Example:
  (geometry-type (make-polyline '())) => polyline"
      (car g))

    (define (geometry-parts g)
      "Syntax: (geometry-parts geometry)
Library: (scm geo)
Description: Returns the parts of geometry: the rings of a polygon, the paths
  of a polyline, the points of a multipoint.
Example:
  (geometry-parts (make-multipoint (list #(1 2)))) => (#(1 2))"
      (cdr g))

    (define (feature-rings f)
      "Syntax: (feature-rings feature)
Library: (scm geo)
Description: Returns the rings of feature's polygon geometry, or the empty list
  when its geometry is not a polygon.
Example:
  (feature-rings (make-feature '() (make-polygon (list #(0 0 1 0 1 1 0 0))))) => (#(0 0 1 0 1 1 0 0))"
      (let ((g (feature-geometry f)))
        (if (and (pair? g) (eq? (car g) 'polygon)) (cdr g) '())))

    ;; --- rings -------------------------------------------------------

    (define (ring-point-count r)
      "Syntax: (ring-point-count ring)
Library: (scm geo)
Description: Returns the number of points in ring (or in any flat coordinate
  vector), counting a closed ring's last point, which repeats its first.
Example:
  (ring-point-count #(0 0 1 0 1 1 0 0)) => 4"
      (quotient (vector-length r) 2))

    (define (ring-area r)
      "Syntax: (ring-area ring)
Library: (scm geo)
Description: Returns the signed planar area of ring, a closed flat coordinate
  vector: positive when the ring runs counter-clockwise (with y pointing up),
  negative when it runs clockwise.
Example:
  (ring-area #(0 0 2 0 2 2 0 2 0 0)) => 4.0"
      (let ((n (vector-length r)))
        (if (< n 6)
            0.0
            (let loop ((i 0) (s 0.0))
              (if (>= i (- n 2))
                  (/ s 2.0)
                  (loop (+ i 2)
                        (+ s (- (* (vector-ref r i) (vector-ref r (+ i 3)))
                                (* (vector-ref r (+ i 2)) (vector-ref r (+ i 1)))))))))))

    (define (rings-area rings)
      "Syntax: (rings-area rings)
Library: (scm geo)
Description: Returns the area enclosed by rings, outer rings counted positive
  and holes negative whatever their orientation: the absolute area of a ring
  inside an even number of other rings is added, the others subtracted.
Example:
  (rings-area (list #(0 0 4 0 4 4 0 4 0 0) #(1 1 1 2 2 2 2 1 1 1))) => 15.0"
      (fold (lambda (r acc)
              (let ((a (abs (ring-area r)))
                    (depth (count (lambda (o)
                                    (and (not (eq? o r))
                                         (point-in-ring? (vector-ref r 0) (vector-ref r 1) o)))
                                  rings)))
                (if (even? depth) (+ acc a) (- acc a))))
            0.0 rings))

    ;; A bbox is #(xmin ymin xmax ymax).
    (define (ring-bbox r)
      "Syntax: (ring-bbox ring)
Library: (scm geo)
Description: Returns the bounding box of ring (or of any flat coordinate
  vector) as #(xmin ymin xmax ymax).
Example:
  (ring-bbox #(0 0 3 1 1 2 0 0)) => #(0 0 3 2)"
      (let ((n (vector-length r)))
        (let loop ((i 2)
                   (x0 (vector-ref r 0)) (y0 (vector-ref r 1))
                   (x1 (vector-ref r 0)) (y1 (vector-ref r 1)))
          (if (>= i n)
              (vector x0 y0 x1 y1)
              (let ((x (vector-ref r i)) (y (vector-ref r (+ i 1))))
                (loop (+ i 2) (min x0 x) (min y0 y) (max x1 x) (max y1 y)))))))

    (define (bbox-union a b)
      "Syntax: (bbox-union a b)
Library: (scm geo)
Description: Returns the smallest bounding box containing the bounding boxes a
  and b; either may be #f, meaning empty.
Example:
  (bbox-union #(0 0 1 1) #(2 -1 3 0)) => #(0 -1 3 1)"
      (cond ((not a) b)
            ((not b) a)
            (else (vector (min (vector-ref a 0) (vector-ref b 0))
                          (min (vector-ref a 1) (vector-ref b 1))
                          (max (vector-ref a 2) (vector-ref b 2))
                          (max (vector-ref a 3) (vector-ref b 3))))))

    (define (bbox-overlap? a b)
      "Syntax: (bbox-overlap? a b)
Library: (scm geo)
Description: Returns #t when the bounding boxes a and b overlap or touch.
Example:
  (bbox-overlap? #(0 0 1 1) #(1 1 2 2)) => #t"
      (and (<= (vector-ref a 0) (vector-ref b 2))
           (<= (vector-ref b 0) (vector-ref a 2))
           (<= (vector-ref a 1) (vector-ref b 3))
           (<= (vector-ref b 1) (vector-ref a 3))))

    (define (rings-bbox rings)
      "Syntax: (rings-bbox rings)
Library: (scm geo)
Description: Returns the bounding box of a list of rings, or #f when the list
  is empty.
Example:
  (rings-bbox (list #(0 0 1 0 0 0) #(5 5 6 6 5 5))) => #(0 0 6 6)"
      (fold (lambda (r acc) (bbox-union acc (ring-bbox r))) #f rings))

    (define (ring-reverse r)
      "Syntax: (ring-reverse ring)
Library: (scm geo)
Description: Returns ring with its points in the opposite order.
Example:
  (ring-reverse #(0 0 1 0 1 1 0 0)) => #(0 0 1 1 1 0 0 0)"
      (let* ((n (vector-length r)) (v (make-vector n)))
        (do ((i 0 (+ i 2))) ((>= i n) v)
          (vector-set! v (- n i 2) (vector-ref r i))
          (vector-set! v (- n i 1) (vector-ref r (+ i 1))))))

    (define (point-in-ring? x y r)
      "Syntax: (point-in-ring? x y ring)
Library: (scm geo)
Description: Returns #t when the point (x, y) lies inside ring (even-odd rule).
  A point exactly on the boundary may count as either.
Example:
  (point-in-ring? 1 1 #(0 0 2 0 2 2 0 2 0 0)) => #t"
      (let ((n (vector-length r)))
        (let loop ((i 0) (inside #f))
          (if (>= i (- n 2))
              inside
              (let ((xa (vector-ref r i)) (ya (vector-ref r (+ i 1)))
                    (xb (vector-ref r (+ i 2))) (yb (vector-ref r (+ i 3))))
                (loop (+ i 2)
                      (if (and (not (eq? (> ya y) (> yb y)))
                               (< x (+ xa (/ (* (- y ya) (- xb xa)) (- yb ya)))))
                          (not inside)
                          inside)))))))

    (define (point-in-rings? x y rings)
      "Syntax: (point-in-rings? x y rings)
Library: (scm geo)
Description: Returns #t when the point (x, y) lies inside an odd number of
  rings, that is inside the polygon they make up.
Example:
  (point-in-rings? 1.5 1.5 (list #(0 0 4 0 4 4 0 4 0 0) #(1 1 1 2 2 2 2 1 1 1))) => #f"
      (odd? (count (lambda (r) (point-in-ring? x y r)) rings)))

    (define (rings->polygons rings)
      "Syntax: (rings->polygons rings)
Library: (scm geo)
Description: Groups rings into polygons and returns a list of them, each a
  list whose first ring is the outer ring and whose other rings are its holes.
  Outer rings are made counter-clockwise and holes clockwise; a hole goes to
  the smallest outer ring that contains it. Rings without area are dropped.
Example:
  (length (rings->polygons (list #(0 0 4 0 4 4 0 4 0 0) #(1 1 2 1 2 2 1 2 1 1)))) => 1"
      (let ((rv (list->vector rings)))
        (map (lambda (p)
               (map (lambda (e)
                      (let ((r (vector-ref rv (car e)))) (if (cdr e) (ring-reverse r) r)))
                    p))
             (ring-groups rings))))

    (define (ring-groups rings)
      "Syntax: (ring-groups rings)
Library: (scm geo)
Description: Groups rings into polygons as rings->polygons does, but returns
  the rings by position: a list of polygons, each a list of pairs (index .
  reverse?), the outer ring first, where index is the position of the ring in
  rings and reverse? tells whether it runs the wrong way (outer rings
  counter-clockwise, holes clockwise).
Example:
  (ring-groups (list #(0 0 4 0 4 4 0 4 0 0) #(1 1 2 1 2 2 1 2 1 1))) => (((0 . #f) (1 . #t)))"
      (let* ((rs (filter-map (lambda (r i)
                               (let ((a (ring-area r)))
                                 (and (not (zero? a)) (list r i a))))
                             rings (iota (length rings))))
             ;; depth: how many larger rings contain the ring
             (depth (lambda (e)
                      (let ((r (car e)))
                        (count (lambda (o)
                                 (and (not (eq? o e))
                                      (< (abs (caddr e)) (abs (caddr o)))
                                      (point-in-ring? (vector-ref r 0) (vector-ref r 1) (car o))))
                               rs))))
             ;; ring index area depth signed-area
             (tagged (map (lambda (e) (list (car e) (abs (caddr e)) (depth e) (caddr e) (cadr e))) rs))
             (outers (filter (lambda (t) (even? (caddr t))) tagged))
             (holes (filter (lambda (t) (odd? (caddr t))) tagged))
             (entry (lambda (t ccw?) (cons (list-ref t 4) (not (eq? ccw? (> (cadddr t) 0))))))
             (groups (map list (sort-by-area outers))))
        (for-each
         (lambda (h)
           (let* ((r (car h)) (x (vector-ref r 0)) (y (vector-ref r 1))
                  (g (find (lambda (g)
                             (let ((o (car g)))
                               (and (= (caddr o) (- (caddr h) 1))
                                    (> (cadr o) (cadr h))
                                    (point-in-ring? x y (car o)))))
                           groups)))
             (when g (set-cdr! g (cons h (cdr g))))))
         holes)
        (map (lambda (g)
               (cons (entry (car g) #t)
                     (map (lambda (h) (entry h #f)) (reverse (cdr g)))))
             (reverse groups))))

    ;; smallest first, so a hole finds its innermost outer ring
    (define (sort-by-area ts)
      (let loop ((ts ts) (out '()))
        (if (null? ts)
            out
            (let ((m (fold (lambda (t m) (if (> (cadr t) (cadr m)) t m)) (car ts) ts)))
              (loop (delete m ts eq?) (cons m out))))))

    ;; --- simplification ---------------------------------------------

    (define (path-dp-thresholds p)
      "Syntax: (path-dp-thresholds path)
Library: (scm geo)
Description: Returns a vector with one Douglas-Peucker removal threshold per
  point of path, a flat coordinate vector: simplifying to a tolerance keeps
  the points whose threshold exceeds it, and the points marked -1 always (the
  ends). Thresholds never grow down the split tree, so this gives exactly what
  Douglas-Peucker gives at that tolerance. A closed path (first point equal to
  last) is first split at the point farthest from its start, which is kept
  like an end, so a ring never collapses to a line.
Example:
  (path-dp-thresholds #(0 0 1 1 2 0)) => #(-1 1 -1)"
      (let* ((n (ring-point-count p))
             (w (make-vector n 0.0))
             (x (lambda (i) (vector-ref p (* 2 i))))
             (y (lambda (i) (vector-ref p (+ 1 (* 2 i)))))
             (dist (lambda (i a b)
                     (let* ((dx (- (x b) (x a))) (dy (- (y b) (y a)))
                            (px (- (x i) (x a))) (py (- (y i) (y a)))
                            (l2 (+ (* dx dx) (* dy dy))))
                       (if (zero? l2)
                           (sqrt (+ (* px px) (* py py)))
                           (let* ((u (max 0 (min 1 (/ (+ (* px dx) (* py dy)) l2))))
                                  (ex (- px (* u dx))) (ey (- py (* u dy))))
                             (sqrt (+ (* ex ex) (* ey ey)))))))))
        (when (> n 0)
          (vector-set! w 0 -1)
          (vector-set! w (- n 1) -1))
        (let ((stack
               (if (and (> n 3) (= (x 0) (x (- n 1))) (= (y 0) (y (- n 1))))
                   (let loop ((i 1) (best 1) (bd -1.0))
                     (if (< i (- n 1))
                         (let* ((dx (- (x i) (x 0))) (dy (- (y i) (y 0)))
                                (d (sqrt (+ (* dx dx) (* dy dy)))))
                           (if (> d bd) (loop (+ i 1) i d) (loop (+ i 1) best bd)))
                         (begin
                           (vector-set! w best -1)
                           (list (list 0 best +inf.0) (list best (- n 1) +inf.0)))))
                   (list (list 0 (- n 1) +inf.0)))))
          (let loop ((stack stack))
            (unless (null? stack)
              (let* ((s (car stack)) (a (car s)) (b (cadr s)) (cap (caddr s)))
                (if (< (- b a) 2)
                    (loop (cdr stack))
                    (let find ((i (+ a 1)) (best -1) (bd -1.0))
                      (if (< i b)
                          (let ((d (dist i a b)))
                            (if (> d bd) (find (+ i 1) i d) (find (+ i 1) best bd)))
                          (let ((v (min bd cap)))
                            (vector-set! w best v)
                            (loop (cons (list a best v)
                                        (cons (list best b v) (cdr stack))))))))))))
        w))

    (define (path-simplify p tolerance . thresholds)
      "Syntax: (path-simplify path tolerance [thresholds])
Library: (scm geo)
Description: Returns path, a flat coordinate vector, simplified with
  Douglas-Peucker to tolerance: every point removed lies within tolerance of
  the simplified line. thresholds, as returned by path-dp-thresholds, saves
  computing them again.
Example:
  (path-simplify #(0 0 1 0.1 2 0) 0.5) => #(0 0 2 0)"
      (let* ((w (if (pair? thresholds) (car thresholds) (path-dp-thresholds p)))
             (n (vector-length w))
             (keep (let loop ((i (- n 1)) (out '()))
                     (if (< i 0)
                         out
                         (let ((t (vector-ref w i)))
                           (loop (- i 1) (if (or (< t 0) (> t tolerance)) (cons i out) out))))))
             (v (make-vector (* 2 (length keep)))))
        (let loop ((ks keep) (j 0))
          (unless (null? ks)
            (vector-set! v j (vector-ref p (* 2 (car ks))))
            (vector-set! v (+ j 1) (vector-ref p (+ 1 (* 2 (car ks)))))
            (loop (cdr ks) (+ j 2))))
        v))

    ;; --- label points ---------------------------------------------

    ;; Signed distance from (x, y) to the polygon made of rings: positive
    ;; inside, negative outside.
    (define (point-polygon-distance x y rings)
      (let ((inside #f) (best +inf.0))
        (for-each
         (lambda (r)
           (let ((n (vector-length r)))
             (let loop ((i 0))
               (when (< i (- n 2))
                 (let* ((ax (vector-ref r i)) (ay (vector-ref r (+ i 1)))
                        (bx (vector-ref r (+ i 2))) (by (vector-ref r (+ i 3))))
                   (when (and (not (eq? (> ay y) (> by y)))
                              (< x (+ ax (/ (* (- y ay) (- bx ax)) (- by ay)))))
                     (set! inside (not inside)))
                   (let* ((dx (- bx ax)) (dy (- by ay))
                          (l2 (+ (* dx dx) (* dy dy)))
                          (u (if (zero? l2) 0
                                 (max 0 (min 1 (/ (+ (* (- x ax) dx) (* (- y ay) dy)) l2)))))
                          (ex (- x (+ ax (* u dx)))) (ey (- y (+ ay (* u dy))))
                          (d2 (+ (* ex ex) (* ey ey))))
                     (when (< d2 best) (set! best d2))))
                 (loop (+ i 2))))))
         rings)
        (if inside (sqrt best) (- (sqrt best)))))

    (define (polygon-inner-point rings . precision)
      "Syntax: (polygon-inner-point rings [precision])
Library: (scm geo)
Description: Returns a point #(x y) inside the polygon made of rings that lies
  as far from its boundary as possible, to within precision (by default a
  thousandth of the polygon's larger side): the pole of inaccessibility, a
  good place for a label. Uses a quadtree search (the polylabel algorithm).
Example:
  (polygon-inner-point (list #(0 0 4 0 4 4 0 4 0 0)) 0.01) => #(2 2)"
      (let* ((bb (rings-bbox rings))
             (x0 (vector-ref bb 0)) (y0 (vector-ref bb 1))
             (w (- (vector-ref bb 2) x0)) (h (- (vector-ref bb 3) y0))
             (size (min w h))
             (prec (if (pair? precision) (car precision) (/ (max w h) 1000.0)))
             (cell (lambda (cx cy half)
                     (let ((d (point-polygon-distance cx cy rings)))
                       ;; x y half distance potential
                       (vector cx cy half d (+ d (* half (sqrt 2.0))))))))
        (if (zero? size)
            (vector x0 y0)
            (let ((heap (make-heap)))
              (let ((half (/ size 2.0)))
                (let yloop ((cy y0))
                  (when (< cy (+ y0 h))
                    (let xloop ((cx x0))
                      (when (< cx (+ x0 w))
                        (heap-push! heap (cell (+ cx half) (+ cy half) half))
                        (xloop (+ cx size))))
                    (yloop (+ cy size)))))
              (let* ((cx (+ x0 (/ w 2.0))) (cy (+ y0 (/ h 2.0)))
                     (best (let ((c (cell cx cy 0)) (d (centroid-cell rings cell)))
                             (if (and d (> (vector-ref d 3) (vector-ref c 3))) d c))))
                (let loop ((best best))
                  (if (heap-empty? heap)
                      (vector (vector-ref best 0) (vector-ref best 1))
                      (let* ((c (heap-pop! heap))
                             (best (if (> (vector-ref c 3) (vector-ref best 3)) c best)))
                        (when (> (- (vector-ref c 4) (vector-ref best 3)) prec)
                          (let ((x (vector-ref c 0)) (y (vector-ref c 1))
                                (hh (/ (vector-ref c 2) 2.0)))
                            (heap-push! heap (cell (- x hh) (- y hh) hh))
                            (heap-push! heap (cell (+ x hh) (- y hh) hh))
                            (heap-push! heap (cell (- x hh) (+ y hh) hh))
                            (heap-push! heap (cell (+ x hh) (+ y hh) hh))))
                        (loop best)))))))))

    ;; the area-weighted centroid of the largest ring as a first guess
    (define (centroid-cell rings cell)
      (let ((r (fold (lambda (r m) (if (or (not m) (> (abs (ring-area r)) (abs (ring-area m)))) r m))
                     #f rings)))
        (and r
             (let ((n (vector-length r)) (a (ring-area r)))
               (and (not (zero? a))
                    (let loop ((i 0) (sx 0.0) (sy 0.0))
                      (if (>= i (- n 2))
                          (cell (/ sx (* 6.0 a)) (/ sy (* 6.0 a)) 0)
                          (let* ((xa (vector-ref r i)) (ya (vector-ref r (+ i 1)))
                                 (xb (vector-ref r (+ i 2))) (yb (vector-ref r (+ i 3)))
                                 (f (- (* xa yb) (* xb ya))))
                            (loop (+ i 2) (+ sx (* (+ xa xb) f)) (+ sy (* (+ ya yb) f)))))))))))

    ;; a max-heap of cells on their potential (slot 4)
    (define (make-heap) (vector (make-vector 64 #f) 0))
    (define (heap-empty? h) (zero? (vector-ref h 1)))
    (define (heap-push! h c)
      (let* ((n (vector-ref h 1))
             (v (let ((v (vector-ref h 0)))
                  (if (< n (vector-length v))
                      v
                      (let ((w (make-vector (* 2 n) #f)))
                        (vector-copy! w 0 v)
                        (vector-set! h 0 w)
                        w)))))
        (vector-set! h 1 (+ n 1))
        (let up ((i n))
          (let ((p (quotient (- i 1) 2)))
            (if (and (> i 0) (> (vector-ref c 4) (vector-ref (vector-ref v p) 4)))
                (begin (vector-set! v i (vector-ref v p)) (up p))
                (vector-set! v i c))))))
    (define (heap-pop! h)
      (let* ((v (vector-ref h 0)) (n (- (vector-ref h 1) 1))
             (top (vector-ref v 0)) (last (vector-ref v n)))
        (vector-set! h 1 n)
        (vector-set! v n #f)
        (when (> n 0)
          (let down ((i 0))
            (let* ((l (+ 1 (* 2 i))) (r (+ l 1))
                   (m (if (and (< l n) (> (vector-ref (vector-ref v l) 4) (vector-ref last 4))) l i))
                   (m (if (and (< r n) (> (vector-ref (vector-ref v r) 4)
                                          (vector-ref (if (= m i) last (vector-ref v m)) 4)))
                          r m)))
              (if (= m i)
                  (vector-set! v i last)
                  (begin (vector-set! v i (vector-ref v m)) (down m))))))
        top))

    ;; --- GeoJSON ---------------------------------------------------

    ;; In the representation of (scm json simple): objects are alists,
    ;; arrays vectors.
    (define (coords->json p)
      (let* ((n (ring-point-count p)) (v (make-vector n)))
        (do ((i 0 (+ i 1))) ((= i n) v)
          (vector-set! v i (vector (vector-ref p (* 2 i)) (vector-ref p (+ 1 (* 2 i))))))))

    (define (json->coords a)
      (let* ((n (vector-length a)) (v (make-vector (* 2 n))))
        (do ((i 0 (+ i 1))) ((= i n) v)
          (let ((pt (vector-ref a i)))
            (vector-set! v (* 2 i) (vector-ref pt 0))
            (vector-set! v (+ 1 (* 2 i)) (vector-ref pt 1))))))

    (define (geometry->json g)
      (case (geometry-type g)
        ((polygon)
         (let ((ps (rings->polygons (geometry-parts g))))
           (if (= (length ps) 1)
               `(("type" . "Polygon")
                 ("coordinates" . ,(list->vector (map coords->json (car ps)))))
               `(("type" . "MultiPolygon")
                 ("coordinates" . ,(list->vector
                                    (map (lambda (p) (list->vector (map coords->json p))) ps)))))))
        ((polyline)
         (let ((ps (geometry-parts g)))
           (if (= (length ps) 1)
               `(("type" . "LineString") ("coordinates" . ,(coords->json (car ps))))
               `(("type" . "MultiLineString")
                 ("coordinates" . ,(list->vector (map coords->json ps)))))))
        ((multipoint)
         (let ((ps (geometry-parts g)))
           (if (= (length ps) 1)
               `(("type" . "Point") ("coordinates" . ,(car ps)))
               `(("type" . "MultiPoint") ("coordinates" . ,(list->vector ps))))))))

    (define (features->geojson features)
      "Syntax: (features->geojson features)
Library: (scm geo)
Description: Returns a GeoJSON FeatureCollection of features, as data for
  (scm json simple): write it with json->string. Polygons have their outer
  rings counter-clockwise and their holes clockwise (RFC 7946).
Example:
  (json->string (features->geojson (list (make-feature '((\"id\" . 1)) (make-multipoint (list #(1 2)))))))
  => \"{\\\"type\\\":\\\"FeatureCollection\\\",\\\"features\\\":[...]}\""
      `(("type" . "FeatureCollection")
        ("features" . ,(list->vector
                        (map (lambda (f)
                               `(("type" . "Feature")
                                 ("properties" . ,(feature-properties f))
                                 ("geometry" . ,(geometry->json (feature-geometry f)))))
                             features)))))

    (define (json->geometry g)
      (let ((type (cdr (assoc "type" g)))
            (cs (cdr (assoc "coordinates" g))))
        (cond ((equal? type "Polygon") (make-polygon (map json->coords (vector->list cs))))
              ((equal? type "MultiPolygon")
               (make-polygon (append-map (lambda (p) (map json->coords (vector->list p)))
                                         (vector->list cs))))
              ((equal? type "LineString") (make-polyline (list (json->coords cs))))
              ((equal? type "MultiLineString") (make-polyline (map json->coords (vector->list cs))))
              ((equal? type "Point") (make-multipoint (list cs)))
              ((equal? type "MultiPoint") (make-multipoint (vector->list cs)))
              (else (error "geojson->features: unsupported geometry" type)))))

    (define (geojson->features json)
      "Syntax: (geojson->features json)
Library: (scm geo)
Description: Returns the features of json, a GeoJSON FeatureCollection as
  parsed by (scm json simple). Features without geometry are skipped.
Example:
  (length (geojson->features (json-parse \"{\\\"type\\\":\\\"FeatureCollection\\\",\\\"features\\\":[]}\"))) => 0"
      (filter-map (lambda (f)
                    (let ((g (assoc "geometry" f))
                          (p (assoc "properties" f)))
                      (and g (pair? (cdr g))
                           (make-feature (if (and p (list? (cdr p))) (cdr p) '())
                                         (json->geometry (cdr g))))))
                  (vector->list (cdr (assoc "features" json)))))))
