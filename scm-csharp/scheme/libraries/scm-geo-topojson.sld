(define-library (scm geo topojson)
  (import (scheme base)
          (scheme inexact)
          (srfi 1)
          (srfi 69)
          (scm geo))
  (export features->topojson
          topojson->features
          topojson-layers)
  (begin

    ;; --- reading ---------------------------------------------------------

    (define (jref obj key default)
      (let ((p (and (list? obj) (assoc key obj)))) (if p (cdr p) default)))

    ;; the arcs of a topology as vectors of points #(x y), decoded
    ;; (delta-encoded and quantized when there is a transform)
    (define (decode-topo-arcs json)
      (let* ((tr (jref json "transform" #f))
             (scale (and tr (jref tr "scale" #f)))
             (translate (and tr (jref tr "translate" #f))))
        (vector-map
         (lambda (arc)
           (if (not scale)
               (vector-map (lambda (p) (vector (inexact (vector-ref p 0)) (inexact (vector-ref p 1)))) arc)
               (let ((n (vector-length arc))
                     (sx (vector-ref scale 0)) (sy (vector-ref scale 1))
                     (tx (vector-ref translate 0)) (ty (vector-ref translate 1)))
                 (let loop ((i 0) (qx 0) (qy 0) (acc '()))
                   (if (= i n)
                       (list->vector (reverse acc))
                       (let* ((d (vector-ref arc i))
                              (qx (+ qx (vector-ref d 0)))
                              (qy (+ qy (vector-ref d 1))))
                         (loop (+ i 1) qx qy
                               (cons (vector (inexact (+ tx (* qx sx))) (inexact (+ ty (* qy sy)))) acc))))))))
         (jref json "arcs" #()))))

    ;; a list of arc indexes -> one flat coordinate vector; ~i is arc i
    ;; reversed, and each arc after the first starts where the previous ended
    (define (stitch arcs indexes)
      (let loop ((is indexes) (first? #t) (acc '()))
        (if (null? is)
            (list->vector (reverse acc))
            (let* ((a (car is))
                   (pts (vector->list (vector-ref arcs (if (< a 0) (- -1 a) a))))
                   (pts (if (< a 0) (reverse pts) pts))
                   (pts (if first? pts (if (pair? pts) (cdr pts) pts))))
              (loop (cdr is) #f
                    (fold (lambda (p acc) (cons (vector-ref p 1) (cons (vector-ref p 0) acc))) acc pts))))))

    (define (point-of json-point transform)
      (let ((x (vector-ref json-point 0)) (y (vector-ref json-point 1)))
        (if transform
            (let ((scale (jref transform "scale" #f)) (translate (jref transform "translate" #f)))
              (vector (inexact (+ (vector-ref translate 0) (* x (vector-ref scale 0))))
                      (inexact (+ (vector-ref translate 1) (* y (vector-ref scale 1))))))
            (vector (inexact x) (inexact y)))))

    ;; a TopoJSON geometry -> a list of features (GeometryCollections
    ;; nest; geometries without a type we know are skipped)
    (define (geometry->features g arcs transform)
      (let* ((type (jref g "type" #f))
             (props (let ((p (jref g "properties" '()))) (if (list? p) p '())))
             (props (let ((id (jref g "id" #f)))
                      (if (and id (not (assoc "id" props))) (cons (cons "id" id) props) props)))
             (rings (lambda (v) (map (lambda (r) (stitch arcs (vector->list r))) (vector->list v))))
             (feature (lambda (geom) (list (make-feature props geom)))))
        (cond
         ((equal? type "GeometryCollection")
          (append-map (lambda (x) (geometry->features x arcs transform)) (vector->list (jref g "geometries" #()))))
         ((equal? type "Polygon") (feature (make-polygon (rings (jref g "arcs" #())))))
         ((equal? type "MultiPolygon")
          (feature (make-polygon (append-map rings (vector->list (jref g "arcs" #()))))))
         ((equal? type "LineString") (feature (make-polyline (list (stitch arcs (vector->list (jref g "arcs" #())))))))
         ((equal? type "MultiLineString") (feature (make-polyline (rings (jref g "arcs" #())))))
         ((equal? type "Point") (feature (make-multipoint (list (point-of (jref g "coordinates" #()) transform)))))
         ((equal? type "MultiPoint")
          (feature (make-multipoint (map (lambda (p) (point-of p transform)) (vector->list (jref g "coordinates" #()))))))
         (else '()))))

    (define (topojson-layers json)
      "Syntax: (topojson-layers json)
Library: (scm geo topojson)
Description: The names of the objects (layers) of a TopoJSON topology,
  json as parsed by (scm json simple).
Example:
  (topojson-layers (json-parse text)) => (\"cantons\" \"lakes\")"
      (map car (jref json "objects" '())))

    (define (topojson->features json . layer)
      "Syntax: (topojson->features json [layer])
Library: (scm geo topojson)
Description: The features of one object (layer) of a TopoJSON topology,
  json as parsed by (scm json simple), by default the first: arcs are
  decoded (with the transform, when quantized) and stitched into rings
  and paths; a MultiPolygon becomes one polygon with all its rings.
  Properties are those of the geometries, plus \"id\" from their id.
Example:
  (topojson->features (json-parse text) \"cantons\")"
      (let* ((objects (jref json "objects" '()))
             (obj (if (pair? layer)
                      (let ((p (assoc (car layer) objects)))
                        (if p (cdr p) (error "topojson->features: no such layer" (car layer) (map car objects))))
                      (if (pair? objects) (cdar objects) (error "topojson->features: no objects"))))
             (arcs (decode-topo-arcs json)))
        (geometry->features obj arcs (jref json "transform" #f))))

    ;; --- writing ---------------------------------------------------------

    ;; Features to a TopoJSON topology. Borders are found by coordinates:
    ;; rings that share a run of vertices (exactly equal coordinates, as
    ;; (scm geo topology) produces them) share one arc there. An arc ends
    ;; where its vertices stop having the same two neighbours, so arcs split
    ;; exactly where the regions on their sides change.

    (define (features->topojson layers . options)
      "Syntax: (features->topojson layers [options])
Library: (scm geo topojson)
Description: Returns a TopoJSON topology of the polygon features in layers, an
  alist from layer name (a string) to a list of features, as data for (scm
  json simple): write it with json->string. Each layer becomes a
  GeometryCollection of Polygon and MultiPolygon geometries with the
  features' properties; borders shared by rings, within a layer or across
  layers, are stored once as shared arcs. Outer rings run clockwise, holes
  counter-clockwise, as TopoJSON tools expect. options is an alist:
  (simplify . tolerance) simplifies every arc with Douglas-Peucker, shared
  arcs once for both sides, so neighbours stay gap-free; rings that would
  collapse keep enough points to stay polygons. (quantization . n) quantizes
  coordinates to an n by n grid and delta-encodes the arcs, adding a
  transform. (thresholds . name) adds a member name with, per arc, the
  Douglas-Peucker removal threshold of each point after quantization (-1 for
  the ends, which are always kept; see path-dp-thresholds), multiplied by
  (threshold-scale . factor), 1 by default, and rounded: with it a reader
  simplifies any arc to any tolerance in one pass.
Example:
  (json->string (features->topojson (list (cons \"cantons\" features))
                                    '((simplify . 20) (quantization . 100000))))"
      (let* ((opts (if (pair? options) (car options) '()))
             (opt (lambda (k d) (let ((o (assq k opts))) (if o (cdr o) d))))
             (tolerance (opt 'simplify #f))
             (q (opt 'quantization #f))
             (thresholds (opt 'thresholds #f))
             (tscale (opt 'threshold-scale 1))
             ;; vertices by coordinates
             (ids (make-hash-table equal?))
             (vx (make-gv)) (vy (make-gv))
             (vertex (lambda (x y)
                       (let ((k (cons x y)))
                         (or (hash-table-ref/default ids k #f)
                             (let ((v (gv-push! vx x)))
                               (gv-push! vy y)
                               (hash-table-set! ids k v)
                               v)))))
             ;; layers -> features -> rings as vertex id vectors, with the
             ;; ring groups (polygons) of each feature
             (layers* (map (lambda (layer)
                             (cons (car layer)
                                   (map (lambda (f)
                                          (let* ((rings (feature-rings f))
                                                 (groups (ring-groups rings)))
                                            (list f groups
                                                  (list->vector (map (lambda (r) (ring-ids r vertex)) rings)))))
                                        (cdr layer))))
                           layers))
             ;; every ring that is part of a polygon
             (all-rings (append-map
                         (lambda (layer)
                           (append-map (lambda (e)
                                         (append-map (lambda (g) (map (lambda (p) (vector-ref (caddr e) (car p))) g))
                                                     (cadr e)))
                                       (cdr layer)))
                         layers*))
             (nv (gv-count vx))
             (X (gv->vector vx)) (Y (gv->vector vy))
             (node? (find-nodes all-rings nv))
             (arcs (make-gv))
             (arc-index (make-hash-table eqv?))
             (ring-arcs (make-hash-table eq?)))
        ;; cut every ring into arcs
        (for-each (lambda (r) (hash-table-set! ring-arcs r (ring->arcs r node? arcs arc-index nv)))
                  all-rings)
        (let* ((arcs (gv->vector arcs))
               (na (vector-length arcs))
               (coords (vector-map (lambda (a) (arc-coords a X Y)) arcs))
               (keep (if tolerance
                         (simplify-arcs coords tolerance all-rings ring-arcs)
                         coords))
               (out (if q (quantize keep q) (vector-map coords->points keep)))
               (json-arcs (if q (vector-map delta-encode (car out)) out))
               (geometry
                (lambda (e)
                  (let* ((f (car e)) (groups (cadr e)) (ids (caddr e))
                         (ring (lambda (i rev?)
                                 ;; TopoJSON wants outer rings clockwise: the
                                 ;; opposite of ring-groups' convention
                                 (let ((as (hash-table-ref ring-arcs (vector-ref ids i) (lambda () '()))))
                                   (list->vector (if rev? as (reverse (map arc-reverse as)))))))
                         (polys (map (lambda (g) (list->vector (map (lambda (p) (ring (car p) (cdr p))) g)))
                                     groups)))
                    `(,@(cond ((null? polys) '(("type" . null)))
                              ((null? (cdr polys)) `(("type" . "Polygon") ("arcs" . ,(car polys))))
                              (else `(("type" . "MultiPolygon") ("arcs" . ,(list->vector polys)))))
                      ("properties" . ,(feature-properties f)))))))
          `(("type" . "Topology")
            ("arcs" . ,json-arcs)
            ,@(if q
                  `(("transform" . (("scale" . ,(vector (vector-ref (cdr out) 0) (vector-ref (cdr out) 1)))
                                    ("translate" . ,(vector (vector-ref (cdr out) 2) (vector-ref (cdr out) 3))))))
                  '())
            ("objects" . ,(map (lambda (layer)
                                 (cons (car layer)
                                       `(("type" . "GeometryCollection")
                                         ("geometries" . ,(list->vector (map geometry (cdr layer)))))))
                               layers*))
            ,@(if thresholds
                  (list (cons thresholds
                              (vector-map (lambda (pts)
                                            (vector-map (lambda (w) (if (< w 0) -1 (exact (round (* w tscale)))))
                                                        (path-dp-thresholds pts)))
                                          (if q (dequantize out) keep))))
                  '())))))

    ;; --- growable vectors -------------------------------------------

    (define (make-gv) (vector (make-vector 1024 0) 0))
    (define (gv-count g) (vector-ref g 1))
    (define (gv-push! g x)
      (let ((v (vector-ref g 0)) (n (vector-ref g 1)))
        (when (= n (vector-length v))
          (let ((w (make-vector (* 2 n) 0)))
            (vector-copy! w 0 v)
            (vector-set! g 0 w)))
        (vector-set! (vector-ref g 0) n x)
        (vector-set! g 1 (+ n 1))
        n))
    (define (gv->vector g) (vector-copy (vector-ref g 0) 0 (vector-ref g 1)))

    ;; see (scm geo topology): keeps both halves of the key apart in its hash
    (define (pair-key a b) (+ (* a 2654435761) b))

    ;; --- arcs ---------------------------------------------------------

    ;; A ring as vertex ids, without the closing point or repeated points.
    (define (ring-ids r vertex)
      (let* ((n (- (ring-point-count r) 1))
             (ids (let loop ((i 0) (out '()))
                    (if (= i n)
                        (reverse out)
                        (let ((v (vertex (vector-ref r (* 2 i)) (vector-ref r (+ 1 (* 2 i))))))
                          (loop (+ i 1) (if (and (pair? out) (= v (car out))) out (cons v out))))))))
        (list->vector (if (and (pair? ids) (pair? (cdr ids)) (= (car ids) (last ids)))
                          (drop-right ids 1)
                          ids))))

    ;; A vertex is a node when it does not have exactly two neighbours
    ;; across all rings.
    (define (find-nodes rings nv)
      (let ((seen (make-hash-table eqv?)) (deg (make-vector nv 0)))
        (for-each
         (lambda (r)
           (let ((n (vector-length r)))
             (do ((i 0 (+ i 1))) ((= i n))
               (let* ((a (vector-ref r i)) (b (vector-ref r (modulo (+ i 1) n)))
                      (k (pair-key (min a b) (max a b))))
                 (unless (or (= a b) (hash-table-ref/default seen k #f))
                   (hash-table-set! seen k #t)
                   (vector-set! deg a (+ 1 (vector-ref deg a)))
                   (vector-set! deg b (+ 1 (vector-ref deg b))))))))
         rings)
        (lambda (v) (not (= (vector-ref deg v) 2)))))

    ;; An arc is a vector of vertex ids. Index i is the arc, ~i = -1 - i the
    ;; arc reversed; arc-index maps the first directed edge of an arc, in
    ;; either direction, to its signed index.
    (define (arc-reverse a) (- -1 a))

    (define (ring->arcs r node? arcs arc-index nv)
      (let* ((n (vector-length r))
             (start (let loop ((i 0)) (cond ((= i n) #f) ((node? (vector-ref r i)) i) (else (loop (+ i 1)))))))
        (if (< n 2)
            '()
            (if (not start)
                ;; no node: one closed arc, started at its lowest vertex and
                ;; running towards the lower of that vertex's neighbours, so
                ;; that both rings around it find the same arc
                (let* ((m (let loop ((i 1) (m 0))
                            (if (= i n) m (loop (+ i 1) (if (< (vector-ref r i) (vector-ref r m)) i m)))))
                       (fwd (< (vector-ref r (modulo (+ m 1) n)) (vector-ref r (modulo (- m 1) n))))
                       (pts (list->vector
                             (map (lambda (k) (vector-ref r (modulo (if fwd (+ m k) (- m k)) n)))
                                  (iota (+ n 1)))))
                       (a (lookup-or-add! pts arcs arc-index nv)))
                  (list (if fwd a (arc-reverse a))))
                ;; split at the nodes
                (let loop ((k 0) (cur (list (vector-ref r start))) (out '()))
                  (if (= k n)
                      (reverse out)
                      (let* ((v (vector-ref r (modulo (+ start k 1) n)))
                             (cur (cons v cur)))
                        (if (node? v)
                            (loop (+ k 1) (list v)
                                  (cons (lookup-or-add! (list->vector (reverse cur)) arcs arc-index nv) out))
                            (loop (+ k 1) cur out)))))))))

    (define (lookup-or-add! pts arcs arc-index nv)
      (let* ((n (vector-length pts))
             (fk (pair-key (vector-ref pts 0) (vector-ref pts 1)))
             (bk (pair-key (vector-ref pts (- n 1)) (vector-ref pts (- n 2)))))
        (or (hash-table-ref/default arc-index fk #f)
            (let ((a (gv-push! arcs pts)))
              (hash-table-set! arc-index fk a)
              (hash-table-set! arc-index bk (arc-reverse a))
              a))))

    (define (arc-coords a X Y)
      (let* ((n (vector-length a)) (v (make-vector (* 2 n))))
        (do ((i 0 (+ i 1))) ((= i n) v)
          (vector-set! v (* 2 i) (vector-ref X (vector-ref a i)))
          (vector-set! v (+ 1 (* 2 i)) (vector-ref Y (vector-ref a i))))))

    ;; --- simplification -----------------------------------------------

    (define (simplify-arcs coords tolerance rings ring-arcs)
      (let* ((na (vector-length coords))
             (w (vector-map path-dp-thresholds coords))
             (tol (make-vector na tolerance))
             (simple (make-vector na #f))
             (arc (lambda (a)
                    (or (vector-ref simple a)
                        (let ((s (path-simplify (vector-ref coords a) (vector-ref tol a) (vector-ref w a))))
                          (vector-set! simple a s)
                          s))))
             (ring-area* (lambda (as)
                           ;; area of the ring the simplified arcs make
                           (let ((pts (append-map (lambda (s)
                                                    (let* ((c (arc (if (< s 0) (arc-reverse s) s)))
                                                           (c (if (< s 0) (ring-reverse c) c)))
                                                      (cddr (vector->list c))))
                                                  as)))
                             (if (< (length pts) 6)
                                 0.0
                                 (ring-area (list->vector (append (take-right pts 2) pts))))))))
        ;; keep shapes: lower the tolerance of the arcs of a collapsing ring
        (for-each
         (lambda (r)
           (let ((as (hash-table-ref/default ring-arcs r '())))
             (let loop ((tries 0))
               (when (and (pair? as) (< tries 30) (zero? (ring-area* as)))
                 (for-each (lambda (s)
                             (let ((a (if (< s 0) (arc-reverse s) s)))
                               (vector-set! tol a (/ (vector-ref tol a) 2))
                               (vector-set! simple a #f)))
                           as)
                 (loop (+ tries 1))))))
         rings)
        (vector-map (lambda (a) (arc a)) (list->vector (iota na)))))

    ;; --- output -------------------------------------------------------

    (define (coords->points c)
      (let* ((n (ring-point-count c)) (v (make-vector n)))
        (do ((i 0 (+ i 1))) ((= i n) v)
          (vector-set! v i (vector (vector-ref c (* 2 i)) (vector-ref c (+ 1 (* 2 i))))))))

    ;; Returns (arcs . #(sx sy tx ty)): arcs as vectors of integer points,
    ;; repeated points dropped.
    (define (quantize arcs q)
      (let* ((bb (fold (lambda (c bb) (bbox-union bb (ring-bbox c))) #f (vector->list arcs)))
             (bb (or bb (vector 0 0 1 1)))
             (tx (vector-ref bb 0)) (ty (vector-ref bb 1))
             (sx (let ((d (- (vector-ref bb 2) tx))) (if (> d 0) (/ d (- q 1)) 1)))
             (sy (let ((d (- (vector-ref bb 3) ty))) (if (> d 0) (/ d (- q 1)) 1))))
        (cons (vector-map
               (lambda (c)
                 (let* ((n (ring-point-count c))
                        (pts (let loop ((i 0) (out '()))
                               (if (= i n)
                                   (reverse out)
                                   (let ((p (vector (exact (round (/ (- (vector-ref c (* 2 i)) tx) sx)))
                                                    (exact (round (/ (- (vector-ref c (+ 1 (* 2 i))) ty) sy))))))
                                     (loop (+ i 1)
                                           (if (and (pair? out) (equal? p (car out))
                                                    (or (< i (- n 1)) (pair? (cdr out))))
                                               out
                                               (cons p out))))))))
                   (list->vector pts)))
               arcs)
              (vector (inexact sx) (inexact sy) tx ty))))

    (define (delta-encode pts)
      (let ((n (vector-length pts)) (v (make-vector (vector-length pts))))
        (do ((i 0 (+ i 1))) ((= i n) v)
          (let ((p (vector-ref pts i)))
            (vector-set! v i
                         (if (zero? i)
                             p
                             (let ((o (vector-ref pts (- i 1))))
                               (vector (- (vector-ref p 0) (vector-ref o 0))
                                       (- (vector-ref p 1) (vector-ref o 1))))))))))

    ;; the quantized arcs as flat coordinate vectors, without the translation
    (define (dequantize out)
      (let ((sx (vector-ref (cdr out) 0)) (sy (vector-ref (cdr out) 1)))
        (vector-map (lambda (pts)
                      (let* ((n (vector-length pts)) (v (make-vector (* 2 n))))
                        (do ((i 0 (+ i 1))) ((= i n) v)
                          (vector-set! v (* 2 i) (* sx (vector-ref (vector-ref pts i) 0)))
                          (vector-set! v (+ 1 (* 2 i)) (* sy (vector-ref (vector-ref pts i) 1))))))
                    (car out))))))
