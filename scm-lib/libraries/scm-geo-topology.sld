(define-library (scm geo topology)
  (import (scheme base)
          (scheme inexact)
          (scheme time)
          (scheme write)
          (srfi 1)
          (srfi 69)
          (scm geo))
  (export make-planar-graph
          planar-graph?
          planar-graph-face-count
          planar-graph-face-features
          planar-graph-face-area
          planar-graph-face-neighbours
          planar-graph-merge-faces!
          planar-graph-components
          planar-graph-dissolve)
  (begin

    ;; A planar graph of polygon features. Every ring of every feature is cut
    ;; into edges at every vertex and every crossing, edges that coincide are
    ;; stored once, and the faces the edges enclose are found. Each face knows
    ;; the features that cover it, whatever layer they came from, so
    ;; dissolving, overlaying and cleaning are all a matter of giving faces
    ;; keys and tracing the borders between faces of different keys.
    ;;
    ;; An edge records, per feature, the winding number change of crossing it
    ;; from its right to its left (from b to a when it runs a -> b): +1 for
    ;; the edge of an outer ring, after every feature's rings have been turned
    ;; so that its total area is positive. A face's winding numbers follow
    ;; from its neighbour's across a shared edge, starting from the face
    ;; outside everything, where all are 0.

    (define-record-type planar-graph
      (%make-planar-graph features vx vy ea eb next hface face-count
                          face-area face-counts neighbours)
      planar-graph?
      (features pg-features)
      (vx pg-vx) (vy pg-vy)
      (ea pg-ea) (eb pg-eb)
      (next pg-next)
      (hface pg-hface)
      (face-count planar-graph-face-count)
      (face-area pg-face-area)
      (face-counts pg-face-counts)
      ;; per face, an alist from neighbouring face to border length; made
      ;; when first asked for
      (neighbours pg-neighbours set-pg-neighbours!))

    ;; --- growable vectors ---------------------------------------------

    (define (make-gv) (vector (make-vector 1024 0) 0))
    (define (gv-count g) (vector-ref g 1))
    (define (gv-ref g i) (vector-ref (vector-ref g 0) i))
    (define (gv-set! g i x) (vector-set! (vector-ref g 0) i x))
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

    ;; --- labels: sorted alists of (feature-index . count) -------------

    (define (labels-add a b sign)
      (cond ((null? b) a)
            ((null? a) (if (= sign 1) b (map (lambda (p) (cons (car p) (- (cdr p)))) b)))
            ((< (caar a) (caar b)) (cons (car a) (labels-add (cdr a) b sign)))
            ((> (caar a) (caar b))
             (cons (cons (caar b) (* sign (cdar b))) (labels-add a (cdr b) sign)))
            (else
             (let ((n (+ (cdar a) (* sign (cdar b)))))
               (if (zero? n)
                   (labels-add (cdr a) (cdr b) sign)
                   (cons (cons (caar a) n) (labels-add (cdr a) (cdr b) sign)))))))

    ;; --- building -----------------------------------------------------

    (define (make-planar-graph layers . options)
      "Syntax: (make-planar-graph layers [options])
Library: (scm geo topology)
Description: Builds the planar graph of the polygon features in layers, a list
  of lists of features (see (scm geo)). Rings are cut at every crossing and at
  every vertex that lies on another ring, coinciding edges are merged, and the
  faces they enclose are found; each face knows the features covering it.
  options is an alist: (snap . distance) merges vertices closer than distance
  and lets a vertex split an edge that passes closer than that; the default is
  a billionth of the extent of the data, enough to absorb rounding.
  (progress . #t) reports each step and its time on the error port.
  Face 0 is the face outside every ring.
Example:
  (planar-graph-face-count
    (make-planar-graph (list (list (make-feature '() (make-polygon (list #(0 0 2 0 2 2 0 2 0 0))))
                                   (make-feature '() (make-polygon (list #(1 1 3 1 3 3 1 3 1 1))))))))
  => 4"
      (let* ((features (list->vector (concatenate layers)))
             (nf (vector-length features))
             (bb (let loop ((i 0) (bb #f))
                   (if (= i nf) bb
                       (loop (+ i 1) (bbox-union bb (rings-bbox (feature-rings (vector-ref features i))))))))
             (bb (or bb (vector 0.0 0.0 1.0 1.0)))
             (x0 (vector-ref bb 0)) (y0 (vector-ref bb 1))
             (extent (max (- (vector-ref bb 2) x0) (- (vector-ref bb 3) y0) 1e-300))
             (opts (if (pair? options) (car options) '()))
             (snap (let ((o (assq 'snap opts)))
                     (if o (cdr o) (* extent 1e-9))))
             (say (make-progress (let ((o (assq 'progress opts))) (and o (cdr o)))))
             (vx (make-gv)) (vy (make-gv))
             (vertex-for (make-snapper vx vy x0 y0 extent snap))
             (edges (make-edge-table)))
        ;; rings to edges
        (do ((fi 0 (+ fi 1))) ((= fi nf))
          (let* ((rings (feature-rings (vector-ref features fi)))
                 (sign (if (< (fold (lambda (r s) (+ s (ring-area r))) 0.0 rings) 0) -1 1))
                 (label (list (cons fi sign))))
            (for-each
             (lambda (r)
               (let ((n (ring-point-count r)))
                 (let loop ((i 1)
                            (a (vertex-for (vector-ref r 0) (vector-ref r 1))))
                   (when (< i n)
                     (let ((b (vertex-for (vector-ref r (* 2 i)) (vector-ref r (+ 1 (* 2 i))))))
                       (edge-add! edges a b label)
                       (loop (+ i 1) b))))))
             rings)))
        (say "~a vertices, ~a edges" (gv-count vx) (edge-count edges))
        ;; cut edges where they cross or touch, until nothing changes
        (let loop ((edges edges) (fresh #f) (pass 0))
          (let-values (((edges* new) (node-edges edges fresh vx vy vertex-for snap say)))
            (say "cut: ~a edges, ~a new" (edge-count edges*) (if new (hash-table-size new) 0))
            (if (and new (< pass 8))
                (loop edges* new (+ pass 1))
                (let ((g (build-faces features vx vy edges*)))
                  (say "~a faces" (planar-graph-face-count g))
                  g))))))

    ;; (say fmt arg ...) with ~a, prefixed by the seconds since the start
    (define (make-progress on)
      (let ((t0 (current-jiffy)))
        (lambda (fmt . args)
          (when on
            (let ((port (current-error-port)))
              (write-string "planar graph " port)
              (write (/ (round (/ (* 10 (- (current-jiffy) t0)) (jiffies-per-second))) 10.0) port)
              (write-string "s: " port)
              (let loop ((cs (string->list fmt)) (args args))
                (cond ((null? cs))
                      ((and (char=? (car cs) #\~) (pair? (cdr cs)))
                       (display (car args) port)
                       (loop (cddr cs) (cdr args)))
                      (else (write-char (car cs) port) (loop (cdr cs) args))))
              (newline port)
              (flush-output-port port))))))

    ;; Vertices closer than tol are one vertex. A grid of cells 16 tol wide;
    ;; neighbouring cells are only searched when the point is near their side.
    (define (make-snapper vx vy x0 y0 extent tol)
      (let* ((cs (* 16.0 tol))
             (stride (+ 2 (exact (ceiling (/ extent cs)))))
             (tol2 (* tol tol))
             (cells (make-hash-table eqv?)))
        (define (in-cell k x y)
          (let loop ((vs (hash-table-ref/default cells k '())))
            (cond ((null? vs) #f)
                  ((let ((dx (- (gv-ref vx (car vs)) x)) (dy (- (gv-ref vy (car vs)) y)))
                     (<= (+ (* dx dx) (* dy dy)) tol2))
                   (car vs))
                  (else (loop (cdr vs))))))
        (lambda (x y)
          (let* ((fx (/ (- x x0) cs)) (fy (/ (- y y0) cs))
                 (cx (+ 1 (exact (floor fx)))) (cy (+ 1 (exact (floor fy))))
                 (k (+ (* cx stride) cy)))
            (or (in-cell k x y)
                (let* ((rx (* cs (- fx (- cx 1)))) (ry (* cs (- fy (- cy 1))))
                       (dxs (cond ((< rx tol) '(-1)) ((> rx (- cs tol)) '(1)) (else '())))
                       (dys (cond ((< ry tol) '(-1)) ((> ry (- cs tol)) '(1)) (else '()))))
                  (and (or (pair? dxs) (pair? dys))
                       (any (lambda (d)
                              (in-cell (+ (* (+ cx (car d)) stride) cy (cdr d)) x y))
                            (append (map (lambda (dx) (cons dx 0)) dxs)
                                    (map (lambda (dy) (cons 0 dy)) dys)
                                    (append-map (lambda (dx) (map (lambda (dy) (cons dx dy)) dys))
                                                dxs)))))
                (let ((v (gv-push! vx (inexact x))))
                  (gv-push! vy (inexact y))
                  (hash-table-set! cells k (cons v (hash-table-ref/default cells k '())))
                  v))))))

    ;; A hash key for two small non-negative integers. Hash tables hash an
    ;; integer by folding its two 32-bit halves together, so a and b must not
    ;; land in separate halves: a * 2^32 + b would hash to about a xor b.
    (define (pair-key a b) (+ (* a 2654435761) b))

    ;; Edges between vertex ids a < b, each once, with their labels.
    (define (make-edge-table)
      (vector (make-hash-table eqv?) (make-gv) (make-gv) (make-gv)))
    (define (edge-count t) (gv-count (vector-ref t 1)))
    (define (edge-a t e) (gv-ref (vector-ref t 1) e))
    (define (edge-b t e) (gv-ref (vector-ref t 2) e))
    (define (edge-labels t e) (gv-ref (vector-ref t 3) e))
    ;; adds the edge a -> b with labels (relative to a -> b); returns its index
    (define (edge-add! t a b labels)
      (if (= a b)
          #f
          (let* ((lo (min a b)) (hi (max a b))
                 (labels (if (< a b) labels (labels-add '() labels -1)))
                 (k (pair-key lo hi))
                 (e (hash-table-ref/default (vector-ref t 0) k #f)))
            (if e
                (begin
                  (gv-set! (vector-ref t 3) e (labels-add (edge-labels t e) labels 1))
                  e)
                (let ((e (gv-push! (vector-ref t 1) lo)))
                  (gv-push! (vector-ref t 2) hi)
                  (gv-push! (vector-ref t 3) labels)
                  (hash-table-set! (vector-ref t 0) k e)
                  e)))))

    ;; One pass: finds where edges cross or where a vertex lies on another
    ;; edge, and returns a new edge table with those edges cut, plus the set
    ;; of edges it created (#f when nothing was cut). fresh limits the pass
    ;; to pairs with at least one edge in it: only those go into the grid.
    (define (node-edges edges fresh vx vy vertex-for tol say)
      (let* ((ne (edge-count edges))
             (tol2 (* tol tol))
             (cuts (make-hash-table eqv?))
             (cut! (lambda (e t v)
                     (hash-table-set! cuts e (cons (cons t v) (hash-table-ref/default cuts e '())))))
             ;; snapshots: the pass only reads vertices that exist already
             (EA (gv->vector (vector-ref edges 1)))
             (EB (gv->vector (vector-ref edges 2)))
             (X (gv->vector vx))
             (Y (gv->vector vy))
             ;; boxes, widened by tol
             (bx0 (make-vector ne 0.0)) (by0 (make-vector ne 0.0))
             (bx1 (make-vector ne 0.0)) (by1 (make-vector ne 0.0))
             (total (let loop ((e 0) (s 0.0))
                      (if (= e ne)
                          s
                          (let* ((a (vector-ref EA e)) (b (vector-ref EB e))
                                 (xa (vector-ref X a)) (xb (vector-ref X b))
                                 (ya (vector-ref Y a)) (yb (vector-ref Y b)))
                            (vector-set! bx0 e (- (if (< xa xb) xa xb) tol))
                            (vector-set! bx1 e (+ (if (< xa xb) xb xa) tol))
                            (vector-set! by0 e (- (if (< ya yb) ya yb) tol))
                            (vector-set! by1 e (+ (if (< ya yb) yb ya) tol))
                            (loop (+ e 1) (+ s (abs (- xa xb)) (abs (- ya yb))))))))
             ;; the grid: cells about twice the mean edge length
             (cs (max (* 2.0 (/ total (max ne 1))) (* 64.0 tol)))
             (grid (make-hash-table eqv?))
             (stride 2654435761))
        (define (cell x) (exact (floor (/ x cs))))
        (define (key cx cy) (+ (* cx stride) cy))
        (define (fresh? e) (or (not fresh) (hash-table-ref/default fresh e #f)))
        ;; a long edge: its box covers more than 8 cells
        (define (long? e)
          (> (* (+ 1 (- (cell (vector-ref bx1 e)) (cell (vector-ref bx0 e))))
                (+ 1 (- (cell (vector-ref by1 e)) (cell (vector-ref by0 e)))))
             8))
        ;; Calls (visit key) for the cells of edge e: every cell of its box
        ;; for a short edge, only the cells along it for a long one.
        (define (edge-cells e visit)
          (let ((cx0 (cell (vector-ref bx0 e))) (cx1 (cell (vector-ref bx1 e)))
                (cy0 (cell (vector-ref by0 e))) (cy1 (cell (vector-ref by1 e))))
            (if (not (long? e))
                (do ((cx cx0 (+ cx 1))) ((> cx cx1))
                  (do ((cy cy0 (+ cy 1))) ((> cy cy1))
                    (visit (key cx cy))))
                (let* ((a (vector-ref EA e)) (b (vector-ref EB e))
                       (ax (vector-ref X a)) (ay (vector-ref Y a))
                       (bx (vector-ref X b)) (by (vector-ref Y b))
                       (y-at (lambda (x)
                               (if (= ax bx) ay
                                   (+ ay (* (- by ay) (/ (- (max (min x (max ax bx)) (min ax bx)) ax)
                                                          (- bx ax))))))))
                  (do ((cx cx0 (+ cx 1))) ((> cx cx1))
                    (let* ((ya (y-at (* cx cs))) (yb (y-at (* (+ cx 1) cs)))
                           (lo (if (= ax bx) (min ay by) (min ya yb)))
                           (hi (if (= ax bx) (max ay by) (max ya yb))))
                      (do ((cy (cell (- lo tol)) (+ cy 1))) ((> cy (cell (+ hi tol))))
                        (visit (key cx cy)))))))))
        ;; touches: vertex p on edge a-b, strictly between its ends
        (define (on-edge p a b)
          (let* ((ax (vector-ref X a)) (ay (vector-ref Y a))
                 (dx (- (vector-ref X b) ax)) (dy (- (vector-ref Y b) ay))
                 (px (- (vector-ref X p) ax)) (py (- (vector-ref Y p) ay))
                 (l2 (+ (* dx dx) (* dy dy))))
            (and (> l2 0)
                 (let ((t (/ (+ (* px dx) (* py dy)) l2)))
                   (and (> t 0) (< t 1)
                        (let ((ex (- px (* t dx))) (ey (- py (* t dy))))
                          (and (<= (+ (* ex ex) (* ey ey)) tol2) t)))))))
        (define (test e f)
          (let ((a (vector-ref EA e)) (b (vector-ref EB e))
                (c (vector-ref EA f)) (d (vector-ref EB f)))
            (let ((touch #f))
              (unless (or (= c a) (= c b))
                (let ((t (on-edge c a b))) (when t (cut! e t c) (set! touch #t))))
              (unless (or (= d a) (= d b))
                (let ((t (on-edge d a b))) (when t (cut! e t d) (set! touch #t))))
              (unless (or (= a c) (= a d))
                (let ((t (on-edge a c d))) (when t (cut! f t a) (set! touch #t))))
              (unless (or (= b c) (= b d))
                (let ((t (on-edge b c d))) (when t (cut! f t b) (set! touch #t))))
              (unless (or touch (= a c) (= a d) (= b c) (= b d))
                (let* ((ax (vector-ref X a)) (ay (vector-ref Y a))
                       (bx (vector-ref X b)) (by (vector-ref Y b))
                       (cx (vector-ref X c)) (cy (vector-ref Y c))
                       (dx (vector-ref X d)) (dy (vector-ref Y d))
                       (rx (- bx ax)) (ry (- by ay)) (sx (- dx cx)) (sy (- dy cy))
                       (den (- (* rx sy) (* ry sx))))
                  (unless (zero? den)
                    (let ((t (/ (- (* (- cx ax) sy) (* (- cy ay) sx)) den))
                          (u (/ (- (* (- cx ax) ry) (* (- cy ay) rx)) den)))
                      (when (and (> t 0) (< t 1) (> u 0) (< u 1))
                        (let ((v (vertex-for (+ ax (* t rx)) (+ ay (* t ry)))))
                          (unless (or (= v a) (= v b)) (cut! e t v))
                          (unless (or (= v c) (= v d)) (cut! f u v)))))))))))
        ;; the grid holds the fresh edges (all of them on the first pass)
        (let ((long (make-vector ne #f)))
          (do ((e 0 (+ e 1))) ((= e ne))
            (when (fresh? e)
              (vector-set! long e (long? e))
              (edge-cells e (lambda (k)
                              (hash-table-set! grid k (cons e (hash-table-ref/default grid k '())))))))
          (say "  grid: ~a cells" (hash-table-size grid))
          ;; Every edge meets the edges in its cells. A pair is tested once:
          ;; from its lower edge when both are in the grid, and in the cell
          ;; holding the low corner of the overlap of their boxes, which both
          ;; short edges are in; a pair with a long edge is tested where first
          ;; met.
          (do ((e 0 (+ e 1))) ((= e ne))
            (let* ((efresh (fresh? e))
                   (ex0 (vector-ref bx0 e)) (ey0 (vector-ref by0 e))
                   (ex1 (vector-ref bx1 e)) (ey1 (vector-ref by1 e))
                   (elong (long? e))
                   (met '()))
              (edge-cells
                      e
                      (lambda (k)
                        (let loop ((fs (hash-table-ref/default grid k '())))
                          (when (pair? fs)
                            (let ((f (car fs)))
                              (when (and (not (= e f))
                                         (or (not efresh) (< e f))
                                         (<= ex0 (vector-ref bx1 f)) (<= (vector-ref bx0 f) ex1)
                                         (<= ey0 (vector-ref by1 f)) (<= (vector-ref by0 f) ey1))
                                (if (or elong (vector-ref long f))
                                    (unless (memv f met)
                                      (set! met (cons f met))
                                      (test e f))
                                    (when (= k (key (cell (max ex0 (vector-ref bx0 f)))
                                                    (cell (max ey0 (vector-ref by0 f)))))
                                      (test e f)))))
                            (loop (cdr fs)))))))))
        (if (zero? (hash-table-size cuts))
            (values edges #f)
            (let ((out (make-edge-table)) (new (make-hash-table eqv?)))
              (do ((e 0 (+ e 1))) ((= e ne))
                (let ((a (edge-a edges e)) (b (edge-b edges e)) (labels (edge-labels edges e))
                      (cs (hash-table-ref/default cuts e #f)))
                  (if (not cs)
                      (edge-add! out a b labels)
                      (let loop ((u a)
                                 (vs (map cdr (sort-pairs cs))))
                        (cond ((null? vs)
                               (let ((n (edge-add! out u b labels)))
                                 (when n (hash-table-set! new n #t))))
                              ((or (= (car vs) u) (= (car vs) b)) (loop u (cdr vs)))
                              (else
                               (let ((n (edge-add! out u (car vs) labels)))
                                 (when n (hash-table-set! new n #t)))
                               (loop (car vs) (cdr vs))))))))
              (values out new)))))

    (define (sort-pairs ps)
      ;; insertion sort on car; an edge has few cuts
      (fold (lambda (p acc)
              (let ins ((acc acc))
                (cond ((null? acc) (list p))
                      ((<= (car p) (caar acc)) (cons p acc))
                      (else (cons (car acc) (ins (cdr acc)))))))
            '() ps))

    ;; --- faces ---------------------------------------------------------

    (define (build-faces features vx vy edges)
      (let* ((ne0 (edge-count edges))
             ;; edges whose labels cancel out border nothing
             (keep (filter (lambda (e) (pair? (edge-labels edges e))) (iota ne0)))
             (ne (length keep))
             (ea (make-vector ne)) (eb (make-vector ne)) (el (make-vector ne))
             (nv (gv-count vx))
             (X (make-vector nv)) (Y (make-vector nv)))
        (do ((v 0 (+ v 1))) ((= v nv))
          (vector-set! X v (gv-ref vx v))
          (vector-set! Y v (gv-ref vy v)))
        (let loop ((ks keep) (i 0))
          (when (pair? ks)
            (vector-set! ea i (edge-a edges (car ks)))
            (vector-set! eb i (edge-b edges (car ks)))
            (vector-set! el i (edge-labels edges (car ks)))
            (loop (cdr ks) (+ i 1))))
        (let* ((nh (* 2 ne))
               (origin (lambda (h) (if (even? h) (vector-ref ea (quotient h 2)) (vector-ref eb (quotient h 2)))))
               (target (lambda (h) (if (even? h) (vector-ref eb (quotient h 2)) (vector-ref ea (quotient h 2)))))
               (deg (make-vector (+ nv 1) 0)))
          ;; outgoing half-edges per vertex, in counter-clockwise order
          (do ((h 0 (+ h 1))) ((= h nh))
            (let ((v (origin h))) (vector-set! deg v (+ 1 (vector-ref deg v)))))
          (let ((start (make-vector (+ nv 1) 0)) (out (make-vector (max nh 1) 0))
                (pos (make-vector (max nh 1) 0)) (angle (make-vector (max nh 1) 0.0)))
            (let loop ((v 0) (s 0))
              (when (<= v nv)
                (vector-set! start v s)
                (when (< v nv) (loop (+ v 1) (+ s (vector-ref deg v))))))
            (let ((fill (vector-copy start)))
              (do ((h 0 (+ h 1))) ((= h nh))
                (let* ((u (origin h)) (w (target h)))
                  (vector-set! angle h (atan (- (vector-ref Y w) (vector-ref Y u))
                                             (- (vector-ref X w) (vector-ref X u))))
                  (vector-set! out (vector-ref fill u) h)
                  (vector-set! fill u (+ 1 (vector-ref fill u))))))
            (do ((v 0 (+ v 1))) ((= v nv))
              (let ((s (vector-ref start v)) (e (vector-ref start (+ v 1))))
                ;; insertion sort by angle
                (do ((i (+ s 1) (+ i 1))) ((>= i e))
                  (let ((h (vector-ref out i)))
                    (let ins ((j (- i 1)))
                      (if (and (>= j s) (> (vector-ref angle (vector-ref out j)) (vector-ref angle h)))
                          (begin (vector-set! out (+ j 1) (vector-ref out j)) (ins (- j 1)))
                          (vector-set! out (+ j 1) h)))))
                (do ((i s (+ i 1))) ((>= i e))
                  (vector-set! pos (vector-ref out i) (- i s)))))
            ;; next: the half-edge after h around the face on its left
            (let ((next (make-vector (max nh 1) 0)))
              (do ((h 0 (+ h 1))) ((= h nh))
                (let* ((t (if (even? h) (+ h 1) (- h 1)))
                       (v (target h))
                       (s (vector-ref start v))
                       (d (- (vector-ref start (+ v 1)) s)))
                  (vector-set! next h (vector-ref out (+ s (modulo (- (vector-ref pos t) 1) d))))))
              (build-cycles features X Y ea eb el next origin))))))

    (define (build-cycles features X Y ea eb el next origin)
      (let* ((ne (vector-length ea)) (nh (* 2 ne)) (nv (vector-length X))
             (cycle (make-vector (max nh 1) -1))
             (c-first (make-gv)) (c-area (make-gv)) (c-bbox (make-gv)))
        ;; trace every cycle once
        (do ((h0 0 (+ h0 1))) ((= h0 nh))
          (when (< (vector-ref cycle h0) 0)
            (let ((c (gv-push! c-first h0)))
              (let loop ((h h0) (area 0.0) (x0 +inf.0) (y0 +inf.0) (x1 -inf.0) (y1 -inf.0))
                (vector-set! cycle h c)
                (let* ((u (origin h)) (w (origin (vector-ref next h)))
                       (xu (vector-ref X u)) (yu (vector-ref Y u))
                       (area (+ area (- (* xu (vector-ref Y w)) (* (vector-ref X w) yu))))
                       (x0 (min x0 xu)) (y0 (min y0 yu)) (x1 (max x1 xu)) (y1 (max y1 yu))
                       (n (vector-ref next h)))
                  (if (= n h0)
                      (begin (gv-push! c-area (/ area 2.0))
                             (gv-push! c-bbox (vector x0 y0 x1 y1)))
                      (loop n area x0 y0 x1 y1)))))))
        (let* ((nc (gv-count c-first))
               ;; connected components, to tell holes from the faces around them
               (parent (make-vector nv 0))
               (find (lambda (v)
                       (let loop ((v v))
                         (let ((p (vector-ref parent v)))
                           (if (= p v) v
                               (let ((g (vector-ref parent p)))
                                 (vector-set! parent v g)
                                 (loop g))))))))
          (do ((v 0 (+ v 1))) ((= v nv)) (vector-set! parent v v))
          (do ((e 0 (+ e 1))) ((= e ne))
            (let ((a (find (vector-ref ea e))) (b (find (vector-ref eb e))))
              (unless (= a b) (vector-set! parent a b))))
          ;; Each component has one clockwise cycle, its outside, which
          ;; belongs to the face around it: the one of least (most negative)
          ;; area. Every other cycle is a face, 1, 2, ...: slivers whose area
          ;; rounds to zero or below too.
          (let* ((comp (lambda (c) (find (origin (gv-ref c-first c)))))
                 (outer (let ((h (make-hash-table eqv?)))
                          (do ((c 0 (+ c 1))) ((= c nc) h)
                            (let* ((k (comp c)) (o (hash-table-ref/default h k #f)))
                              (when (or (not o) (< (gv-ref c-area c) (gv-ref c-area o)))
                                (hash-table-set! h k c))))))
                 (outer? (lambda (c) (= c (hash-table-ref outer (comp c) (lambda () -1)))))
                 (face-of (make-vector (max nc 1) 0))
                 (nfaces (let loop ((c 0) (f 1))
                           (cond ((= c nc) f)
                                 ((not (outer? c)) (vector-set! face-of c f) (loop (+ c 1) (+ f 1)))
                                 (else (loop (+ c 1) f)))))
                 (face-area (make-vector nfaces 0.0))
                 (in-cycle? (lambda (c x y)
                              (let ((h0 (gv-ref c-first c)))
                                (let loop ((h h0) (inside #f))
                                  (let* ((u (origin h)) (w (origin (vector-ref next h)))
                                         (xa (vector-ref X u)) (ya (vector-ref Y u))
                                         (xb (vector-ref X w)) (yb (vector-ref Y w))
                                         (inside (if (and (not (eq? (> ya y) (> yb y)))
                                                          (< x (+ xa (/ (* (- y ya) (- xb xa)) (- yb ya)))))
                                                     (not inside) inside))
                                         (n (vector-ref next h)))
                                    (if (= n h0) inside (loop n inside)))))))
                 (index (make-cycle-index c-bbox outer? nc)))
            (do ((c 0 (+ c 1))) ((= c nc))
              (unless (outer? c)
                (vector-set! face-area (vector-ref face-of c) (max 0.0 (gv-ref c-area c)))))
            (do ((c 0 (+ c 1))) ((= c nc))
              (when (outer? c)
                (let* ((v (origin (gv-ref c-first c))) (x (vector-ref X v)) (y (vector-ref Y v))
                       (k (comp c))
                       (best (fold (lambda (o best)
                                     (if (and (not (= (comp o) k))
                                              (let ((bb (gv-ref c-bbox o)))
                                                (and (<= (vector-ref bb 0) x (vector-ref bb 2))
                                                     (<= (vector-ref bb 1) y (vector-ref bb 3))))
                                              (or (not best) (< (gv-ref c-area o) (gv-ref c-area best)))
                                              (in-cycle? o x y))
                                         o best))
                                   #f (index x y))))
                  (when best
                    (let ((f (vector-ref face-of best)))
                      (vector-set! face-of c f)
                      (vector-set! face-area f (max 0.0 (+ (vector-ref face-area f) (gv-ref c-area c)))))))))
            (let ((hface (make-vector (max nh 1) 0)))
              (do ((h 0 (+ h 1))) ((= h nh))
                (vector-set! hface h (vector-ref face-of (vector-ref cycle h))))
              (%make-planar-graph features X Y ea eb next hface nfaces face-area
                                  (face-labels ne el hface nfaces) #f))))))

    ;; The face cycles by grid cell of their boxes, for finding the face
    ;; around a hole.
    (define (make-cycle-index c-bbox outer? nc)
      (let* ((bb (let loop ((c 0) (bb #f))
                   (if (= c nc) (or bb (vector 0 0 1 1))
                       (loop (+ c 1) (if (outer? c) bb (bbox-union bb (gv-ref c-bbox c)))))))
             (n 128)
             (x0 (vector-ref bb 0)) (y0 (vector-ref bb 1))
             (w (/ (max (- (vector-ref bb 2) x0) 1e-300) n))
             (h (/ (max (- (vector-ref bb 3) y0) 1e-300) n))
             (cells (make-vector (* n n) '()))
             (ix (lambda (x) (max 0 (min (- n 1) (exact (floor (/ (- x x0) w)))))))
             (iy (lambda (y) (max 0 (min (- n 1) (exact (floor (/ (- y y0) h))))))))
        (do ((c 0 (+ c 1))) ((= c nc))
          (unless (outer? c)
            (let ((b (gv-ref c-bbox c)))
              (do ((i (ix (vector-ref b 0)) (+ i 1))) ((> i (ix (vector-ref b 2))))
                (do ((j (iy (vector-ref b 1)) (+ j 1))) ((> j (iy (vector-ref b 3))))
                  (vector-set! cells (+ (* i n) j) (cons c (vector-ref cells (+ (* i n) j)))))))))
        (lambda (x y)
          (if (and (<= x0 x (vector-ref bb 2)) (<= y0 y (vector-ref bb 3)))
              (vector-ref cells (+ (* (ix x) n) (iy y)))
              '()))))

    ;; Winding numbers per face, spreading out from face 0 across edges.
    (define (face-labels ne el hface nfaces)
      (let ((adj (make-vector nfaces '()))
            (labels (make-vector nfaces #f)))
        (do ((e 0 (+ e 1))) ((= e ne))
          (let ((l (vector-ref hface (* 2 e))) (r (vector-ref hface (+ 1 (* 2 e)))))
            (unless (= l r)
              (vector-set! adj l (cons e (vector-ref adj l)))
              (vector-set! adj r (cons e (vector-ref adj r))))))
        (vector-set! labels 0 '())
        (let loop ((queue (list 0)) (later '()))
          (cond ((pair? queue)
                 (let* ((f (car queue)) (lf (vector-ref labels f)))
                   (loop (cdr queue)
                         (fold (lambda (e later)
                                 (let* ((l (vector-ref hface (* 2 e)))
                                        (r (vector-ref hface (+ 1 (* 2 e)))))
                                   (cond ((and (= f r) (not (vector-ref labels l)))
                                          (vector-set! labels l (labels-add lf (vector-ref el e) 1))
                                          (cons l later))
                                         ((and (= f l) (not (vector-ref labels r)))
                                          (vector-set! labels r (labels-add lf (vector-ref el e) -1))
                                          (cons r later))
                                         (else later))))
                               later (vector-ref adj f)))))
                ((pair? later) (loop later '()))))
        (do ((f 0 (+ f 1))) ((= f nfaces))
          (unless (vector-ref labels f) (vector-set! labels f '())))
        labels))

    ;; --- queries -------------------------------------------------------

    (define (planar-graph-face-features g f)
      "Syntax: (planar-graph-face-features graph face)
Library: (scm geo topology)
Description: Returns the features covering face of graph, in the order of the
  layers and features given to make-planar-graph: none for face 0, the
  outside, and for gaps; more than one where features overlap.
Example:
  (planar-graph-face-features g 1) => (#<feature>)"
      (let ((fs (pg-features g)))
        (filter-map (lambda (p) (and (> (cdr p) 0) (vector-ref fs (car p))))
                    (vector-ref (pg-face-counts g) f))))

    (define (planar-graph-face-area g f)
      "Syntax: (planar-graph-face-area graph face)
Library: (scm geo topology)
Description: Returns the area of face of graph, without the holes in it. Face 0,
  the outside, has area 0.
Example:
  (planar-graph-face-area g 1) => 3.0"
      (vector-ref (pg-face-area g) f))

    (define (edge-length g e)
      (let* ((a (vector-ref (pg-ea g) e)) (b (vector-ref (pg-eb g) e))
             (dx (- (vector-ref (pg-vx g) a) (vector-ref (pg-vx g) b)))
             (dy (- (vector-ref (pg-vy g) a) (vector-ref (pg-vy g) b))))
        (sqrt (+ (* dx dx) (* dy dy)))))

    (define (neighbour-table g)
      (or (pg-neighbours g)
          (let ((t (make-neighbour-table g)))
            (set-pg-neighbours! g t)
            t)))

    (define (make-neighbour-table g)
      (let* ((hface (pg-hface g)) (ne (vector-length (pg-ea g)))
             (t (make-vector (planar-graph-face-count g) '())))
        (do ((e 0 (+ e 1))) ((= e ne) t)
          (let ((l (vector-ref hface (* 2 e))) (r (vector-ref hface (+ 1 (* 2 e)))))
            (unless (= l r)
              (let ((len (edge-length g e)))
                (for-each
                 (lambda (a b)
                   (let ((p (assv b (vector-ref t a))))
                     (if p
                         (set-cdr! p (+ (cdr p) len))
                         (vector-set! t a (cons (cons b len) (vector-ref t a))))))
                 (list l r) (list r l))))))))

    (define (planar-graph-face-neighbours g f)
      "Syntax: (planar-graph-face-neighbours graph face)
Library: (scm geo topology)
Description: Returns the faces bordering face of graph as an alist from face to
  the length of the border they share.
Example:
  (planar-graph-face-neighbours g 1) => ((0 . 6.0) (2 . 2.0))"
      (vector-ref (neighbour-table g) f))

    (define (planar-graph-merge-faces! g keys merge?)
      "Syntax: (planar-graph-merge-faces! graph keys merge?)
Library: (scm geo topology)
Description: keys is a vector with one key per face of graph, as for
  planar-graph-dissolve. Gives every face for which (merge? face) is true the
  key of the neighbour it shares the longest border with, among the neighbours
  with a key other than #f that are not to be merged themselves, repeating
  until no more faces can be given a key; this fills gaps and removes slivers.
  Returns keys, which is modified.
Example:
  (planar-graph-merge-faces! g keys (lambda (f) (< (planar-graph-face-area g f) 10))) => #(...)"
      (let* ((nb (neighbour-table g))
             (n (planar-graph-face-count g))
             (pending (make-vector n #f)))
        (do ((f 1 (+ f 1))) ((>= f n))
          (when (merge? f) (vector-set! pending f #t)))
        (let loop ()
          (let ((changed #f))
            (do ((f 1 (+ f 1))) ((>= f n))
              (when (vector-ref pending f)
                (let ((best (fold (lambda (p best)
                                    (if (and (not (vector-ref pending (car p)))
                                             (vector-ref keys (car p))
                                             (or (not best) (> (cdr p) (cdr best))))
                                        p best))
                                  #f (vector-ref nb f))))
                  (when best
                    (vector-set! keys f (vector-ref keys (car best)))
                    (vector-set! pending f #f)
                    (set! changed #t)))))
            (when changed (loop))))
        keys))

    (define (planar-graph-components g keys)
      "Syntax: (planar-graph-components graph keys)
Library: (scm geo topology)
Description: keys is a vector with one key per face of graph, as for
  planar-graph-dissolve. Returns a vector with one number per face naming the
  connected part it belongs to: faces with equal keys (equal?) that share a
  border are in the same part. Faces with key #f get -1. With
  planar-graph-face-area this tells the size of each part of a dissolved
  region, to find its slivers.
Example:
  (planar-graph-components g (vector #f 'a 'a 'b)) => #(-1 1 1 3)"
      (let* ((n (planar-graph-face-count g))
             (parent (make-vector n 0))
             (find (lambda (f)
                     (let loop ((f f))
                       (let ((p (vector-ref parent f)))
                         (if (= p f) f
                             (let ((q (vector-ref parent p)))
                               (vector-set! parent f q)
                               (loop q))))))))
        (do ((f 0 (+ f 1))) ((= f n)) (vector-set! parent f f))
        (do ((f 0 (+ f 1))) ((= f n))
          (let ((k (vector-ref keys f)))
            (when k
              (for-each (lambda (p)
                          (when (equal? k (vector-ref keys (car p)))
                            (let ((a (find f)) (b (find (car p))))
                              (unless (= a b) (vector-set! parent (max a b) (min a b))))))
                        (vector-ref (neighbour-table g) f)))))
        (let ((out (make-vector n -1)))
          (do ((f 0 (+ f 1))) ((= f n) out)
            (when (vector-ref keys f) (vector-set! out f (find f)))))))

    ;; --- dissolving ------------------------------------------------------

    (define (planar-graph-dissolve g keys)
      "Syntax: (planar-graph-dissolve graph keys)
Library: (scm geo topology)
Description: Merges the faces of graph by key and returns an alist from each key
  to the rings outlining its faces (outer rings counter-clockwise, holes
  clockwise), in order of first appearance. keys is a vector with one key per
  face, or a procedure from face to key; keys are compared with equal?, and
  faces with key #f are left out. Faces with the same key share no border in
  the result, faces with different keys share their borders exactly: the
  rings use the same vertices on both sides.
Example:
  (planar-graph-dissolve g (lambda (f) (and (pair? (planar-graph-face-features g f)) 'all)))
  => ((all #(0 0 2 0 2 1 3 1 3 3 1 3 1 2 0 2 0 0)))"
      (let* ((n (planar-graph-face-count g))
             (key (if (procedure? keys) keys (lambda (f) (vector-ref keys f))))
             (ids (make-hash-table equal?))
             (gid (make-vector n -1))
             (order (let loop ((f 0) (order '()))
                      (if (= f n)
                          (reverse order)
                          (let ((k (key f)))
                            (if (not k)
                                (loop (+ f 1) order)
                                (let ((i (hash-table-ref/default ids k #f)))
                                  (if i
                                      (begin (vector-set! gid f i) (loop (+ f 1) order))
                                      (let ((i (hash-table-size ids)))
                                        (hash-table-set! ids k i)
                                        (vector-set! gid f i)
                                        (loop (+ f 1) (cons k order))))))))))
             (rings (make-vector (hash-table-size ids) '()))
             (next (pg-next g)) (hface (pg-hface g))
             (nh (vector-length hface))
             (ea (pg-ea g)) (eb (pg-eb g)) (X (pg-vx g)) (Y (pg-vy g))
             (twin (lambda (h) (if (even? h) (+ h 1) (- h 1))))
             (origin (lambda (h) (if (even? h) (vector-ref ea (quotient h 2)) (vector-ref eb (quotient h 2)))))
             (group (lambda (h) (vector-ref gid (vector-ref hface h))))
             (border? (lambda (h) (let ((i (group h))) (and (>= i 0) (not (= i (group (twin h))))))))
             (seen (make-vector (max nh 1) #f)))
        (when (> (vector-length (pg-ea g)) 0)
          (do ((h0 0 (+ h0 1))) ((= h0 nh))
            (when (and (not (vector-ref seen h0)) (border? h0))
              (let loop ((h h0) (pts '()))
                (vector-set! seen h #t)
                (let* ((v (origin h))
                       (pts (cons (vector-ref Y v) (cons (vector-ref X v) pts)))
                       (n (let turn ((c (vector-ref next h)))
                            (if (border? c) c (turn (vector-ref next (twin c)))))))
                  (if (= n h0)
                      (let* ((v0 (origin h0))
                             (ring (list->vector (reverse (cons (vector-ref Y v0) (cons (vector-ref X v0) pts)))))
                             (i (group h0)))
                        (vector-set! rings i (cons ring (vector-ref rings i))))
                      (loop n pts)))))))
        (map (lambda (k) (cons k (reverse (vector-ref rings (hash-table-ref ids k (lambda () 0))))))
             order)))))
