;; (scm raster) — anti-aliased 2D rasterization into an RGBA canvas.
;;
;; Paths are lists of absolute commands, as in SVG:
;;
;;   (M x y)  (L x y)  (Q x1 y1 x y)  (C x1 y1 x2 y2 x y)  (Z)
;;
;; Filling flattens curves, applies the transform, and accumulates exact
;; signed area coverage per pixel (the algorithm of font-rs): one pass
;; per edge and row, then a running sum along each row. Strokes are turned
;; into polygons (one quad per segment, plus joins and caps, all wound the
;; same way) and filled with the non-zero rule, so their union comes out
;; right. Paint is an rgba colour or a procedure of the pixel centre.
;;
;; Pure Scheme: no native graphics library is used.

(define-library (scm raster)
  (export make-canvas
          canvas?
          canvas-width
          canvas-height
          canvas-pixels
          canvas-ref
          canvas-fill-path!
          canvas-stroke-path!
          canvas->png
          rgba
          transform-identity
          transform-translate
          transform-scale
          transform-rotate
          transform-multiply
          transform-apply
          path-rect
          path-circle
          path-ellipse
          path-polyline)
  (import (scheme base)
          (scheme inexact)
          (scheme cxr)
          (scm png))
  (begin

    ;; --- colours ------------------------------------------------------

    (define (rgba r g b . a)
      "Syntax: (rgba r g b [a])
Library: (scm raster)
Description: Returns a colour usable as paint: r, g and b are integers from
  0 to 255, a is the opacity from 0.0 to 1.0 (default 1.0).
Example:
  (rgba 42 120 214)       ; opaque blue
  (rgba 0 0 0 0.1)        ; a light shade"
      (vector r g b (if (pair? a) (inexact (car a)) 1.0)))

    ;; --- canvas -------------------------------------------------------

    ;; pixels: straight (not premultiplied) RGBA, 4 bytes per pixel
    (define-record-type canvas
      (%make-canvas width height pixels)
      canvas?
      (width canvas-width)
      (height canvas-height)
      (pixels canvas-pixels))

    (define (make-canvas width height . background)
      "Syntax: (make-canvas width height [background])
Library: (scm raster)
Description: Returns a new canvas of width x height pixels, filled with
  the colour background (from rgba), or transparent without one.
Example:
  (make-canvas 200 100 (rgba 255 255 255))"
      (let ((px (make-bytevector (* width height 4) 0)))
        (when (pair? background)
          (let* ((c (car background))
                 (a (exact (round (* 255 (vector-ref c 3))))))
            (do ((k 0 (+ k 4))) ((= k (bytevector-length px)))
              (bytevector-u8-set! px k (vector-ref c 0))
              (bytevector-u8-set! px (+ k 1) (vector-ref c 1))
              (bytevector-u8-set! px (+ k 2) (vector-ref c 2))
              (bytevector-u8-set! px (+ k 3) a))))
        (%make-canvas width height px)))

    (define (canvas-ref canvas x y)
      "Syntax: (canvas-ref canvas x y)
Library: (scm raster)
Description: Returns the pixel at column x, row y as a list (r g b a) of
  integers from 0 to 255.
Example:
  (canvas-ref (make-canvas 1 1 (rgba 255 0 0)) 0 0) => (255 0 0 255)"
      (let ((px (canvas-pixels canvas))
            (k (* 4 (+ x (* y (canvas-width canvas))))))
        (list (bytevector-u8-ref px k) (bytevector-u8-ref px (+ k 1))
              (bytevector-u8-ref px (+ k 2)) (bytevector-u8-ref px (+ k 3)))))

    (define (canvas->png canvas)
      "Syntax: (canvas->png canvas)
Library: (scm raster)
Description: Encodes the canvas as a PNG (RGBA) and returns the bytes as a
  bytevector.
Example:
  (canvas->png (make-canvas 10 10 (rgba 255 255 255)))"
      (png-encode-rgba (canvas-width canvas) (canvas-height canvas)
                       (canvas-pixels canvas)))

    ;; --- transforms ---------------------------------------------------

    ;; #(a b c d e f) as in SVG: x' = a x + c y + e, y' = b x + d y + f

    (define (transform-identity)
      "Syntax: (transform-identity)
Library: (scm raster)
Description: Returns the identity transform. Transforms are vectors
  #(a b c d e f) mapping (x, y) to (a x + c y + e, b x + d y + f), as the
  SVG matrix() does.
Example:
  (transform-identity) => #(1.0 0.0 0.0 1.0 0.0 0.0)"
      (vector 1.0 0.0 0.0 1.0 0.0 0.0))

    (define (transform-translate tx ty)
      "Syntax: (transform-translate tx ty)
Library: (scm raster)
Description: Returns a transform that moves by tx, ty.
Example:
  (transform-apply (transform-translate 5 1) 1 1) => (6.0 . 2.0)"
      (vector 1.0 0.0 0.0 1.0 (inexact tx) (inexact ty)))

    (define (transform-scale sx . sy)
      "Syntax: (transform-scale sx [sy])
Library: (scm raster)
Description: Returns a transform that scales by sx horizontally and sy
  vertically (sy defaults to sx).
Example:
  (transform-apply (transform-scale 2) 3 4) => (6.0 . 8.0)"
      (let ((sy (if (pair? sy) (car sy) sx)))
        (vector (inexact sx) 0.0 0.0 (inexact sy) 0.0 0.0)))

    (define (transform-rotate degrees)
      "Syntax: (transform-rotate degrees)
Library: (scm raster)
Description: Returns a transform that rotates by degrees around the
  origin; positive turns the x axis towards the y axis (clockwise on a
  canvas, where y points down).
Example:
  (transform-apply (transform-rotate 90) 1 0) ; => approximately (0 . 1)"
      (let* ((r (* degrees (/ (* 4 (atan 1)) 180)))
             (c (cos r)) (s (sin r)))
        (vector c s (- s) c 0.0 0.0)))

    (define (transform-multiply m n)
      "Syntax: (transform-multiply m n)
Library: (scm raster)
Description: Returns the transform that applies n first, then m (the
  matrix product m * n).
Example:
  (transform-multiply (transform-translate 10 0) (transform-scale 2))"
      (let ((a (vector-ref m 0)) (b (vector-ref m 1)) (c (vector-ref m 2))
            (d (vector-ref m 3)) (e (vector-ref m 4)) (f (vector-ref m 5))
            (a2 (vector-ref n 0)) (b2 (vector-ref n 1)) (c2 (vector-ref n 2))
            (d2 (vector-ref n 3)) (e2 (vector-ref n 4)) (f2 (vector-ref n 5)))
        (vector (+ (* a a2) (* c b2)) (+ (* b a2) (* d b2))
                (+ (* a c2) (* c d2)) (+ (* b c2) (* d d2))
                (+ (* a e2) (* c f2) e) (+ (* b e2) (* d f2) f))))

    (define (transform-apply m x y)
      "Syntax: (transform-apply m x y)
Library: (scm raster)
Description: Returns the transformed point as a pair (x . y).
Example:
  (transform-apply (transform-scale 2 3) 1 1) => (2.0 . 3.0)"
      (cons (+ (* (vector-ref m 0) x) (* (vector-ref m 2) y) (vector-ref m 4))
            (+ (* (vector-ref m 1) x) (* (vector-ref m 3) y) (vector-ref m 5))))

    ;; How much the transform scales lengths, for stroke widths and the
    ;; flattening tolerance: the square root of the area factor.
    (define (transform-scale-factor m)
      (sqrt (abs (- (* (vector-ref m 0) (vector-ref m 3))
                    (* (vector-ref m 1) (vector-ref m 2))))))

    ;; --- path constructors --------------------------------------------

    ;; The circle constant for a quarter arc as a cubic Bezier.
    (define kappa 0.5522847498307936)

    (define (path-ellipse cx cy rx ry)
      "Syntax: (path-ellipse cx cy rx ry)
Library: (scm raster)
Description: Returns a closed path for the ellipse centred on cx, cy with
  radii rx and ry, as four cubic arcs.
Example:
  (path-ellipse 50 50 40 20)"
      (let ((kx (* kappa rx)) (ky (* kappa ry)))
        `((M ,(+ cx rx) ,cy)
          (C ,(+ cx rx) ,(+ cy ky) ,(+ cx kx) ,(+ cy ry) ,cx ,(+ cy ry))
          (C ,(- cx kx) ,(+ cy ry) ,(- cx rx) ,(+ cy ky) ,(- cx rx) ,cy)
          (C ,(- cx rx) ,(- cy ky) ,(- cx kx) ,(- cy ry) ,cx ,(- cy ry))
          (C ,(+ cx kx) ,(- cy ry) ,(+ cx rx) ,(- cy ky) ,(+ cx rx) ,cy)
          (Z))))

    (define (path-circle cx cy r)
      "Syntax: (path-circle cx cy r)
Library: (scm raster)
Description: Returns a closed path for the circle centred on cx, cy with
  radius r.
Example:
  (path-circle 50 50 10)"
      (path-ellipse cx cy r r))

    (define (path-rect x y w h . radii)
      "Syntax: (path-rect x y w h [rx [ry]])
Library: (scm raster)
Description: Returns a closed path for the rectangle at x, y of size w x
  h, with corners rounded by rx and ry (ry defaults to rx), each limited to
  half the side as in SVG.
Example:
  (path-rect 0 0 100 50)
  (path-rect 0 0 100 50 4)"
      (let* ((rx0 (if (pair? radii) (car radii) 0))
             (ry0 (if (and (pair? radii) (pair? (cdr radii))) (cadr radii) rx0))
             (rx (min (abs rx0) (/ w 2)))
             (ry (min (abs ry0) (/ h 2))))
        (if (or (<= rx 0) (<= ry 0))
            `((M ,x ,y) (L ,(+ x w) ,y) (L ,(+ x w) ,(+ y h)) (L ,x ,(+ y h)) (Z))
            (let ((kx (* kappa rx)) (ky (* kappa ry))
                  (x1 (+ x w)) (y1 (+ y h)))
              `((M ,(+ x rx) ,y)
                (L ,(- x1 rx) ,y)
                (C ,(+ (- x1 rx) kx) ,y ,x1 ,(- (+ y ry) ky) ,x1 ,(+ y ry))
                (L ,x1 ,(- y1 ry))
                (C ,x1 ,(+ (- y1 ry) ky) ,(+ (- x1 rx) kx) ,y1 ,(- x1 rx) ,y1)
                (L ,(+ x rx) ,y1)
                (C ,(- (+ x rx) kx) ,y1 ,x ,(+ (- y1 ry) ky) ,x ,(- y1 ry))
                (L ,x ,(+ y ry))
                (C ,x ,(- (+ y ry) ky) ,(- (+ x rx) kx) ,y ,(+ x rx) ,y)
                (Z))))))

    (define (path-polyline points . closed)
      "Syntax: (path-polyline points [closed?])
Library: (scm raster)
Description: Returns a path through points, a list of pairs (x . y),
  closed when closed? is true.
Example:
  (path-polyline '((0 . 0) (10 . 0) (10 . 10)) #t)"
      (if (null? points)
          '()
          (append (list (list 'M (caar points) (cdar points)))
                  (map (lambda (p) (list 'L (car p) (cdr p))) (cdr points))
                  (if (and (pair? closed) (car closed)) '((Z)) '()))))

    ;; --- flattening ---------------------------------------------------

    ;; Maximum distance, in pixels, between a curve and its polyline.
    (define tolerance 0.2)

    ;; -> list of (closed? . points), points a list of (x . y) in device
    ;; space, each subpath at least one point long
    (define (flatten path m)
      (let ((tx (lambda (x y) (transform-apply m x y))))
        (let loop ((cmds path) (cur '()) (start #f) (pen #f) (out '()))
          (define (finish closed?)
            (if (pair? cur) (cons (cons closed? (reverse cur)) out) out))
          (if (null? cmds)
              (reverse (finish #f))
              (let* ((c (car cmds)) (op (car c)))
                (case op
                  ((M)
                   (let ((p (tx (cadr c) (caddr c))))
                     (loop (cdr cmds) (list p) p p (finish #f))))
                  ((L)
                   (let ((p (tx (cadr c) (caddr c))))
                     (loop (cdr cmds) (cons p (if (pair? cur) cur (list pen)))
                           (or start pen) p out)))
                  ((Q)
                   (let* ((p1 (tx (list-ref c 1) (list-ref c 2)))
                          (p2 (tx (list-ref c 3) (list-ref c 4)))
                          (pts (flatten-quad pen p1 p2)))
                     (loop (cdr cmds) (append (reverse pts) (if (pair? cur) cur (list pen)))
                           (or start pen) p2 out)))
                  ((C)
                   (let* ((p1 (tx (list-ref c 1) (list-ref c 2)))
                          (p2 (tx (list-ref c 3) (list-ref c 4)))
                          (p3 (tx (list-ref c 5) (list-ref c 6)))
                          (pts (flatten-cubic pen p1 p2 p3)))
                     (loop (cdr cmds) (append (reverse pts) (if (pair? cur) cur (list pen)))
                           (or start pen) p3 out)))
                  ((Z)
                   ;; the pen returns to the subpath's start
                   (loop (cdr cmds) '() start start (finish #t)))
                  (else (error "path: unknown command" c))))))))

    (define (dist2 ax ay) (+ (* ax ax) (* ay ay)))

    ;; points after p0, up to and including p2
    (define (flatten-quad p0 p1 p2)
      (let* ((ddx (+ (car p0) (* -2 (car p1)) (car p2)))
             (ddy (+ (cdr p0) (* -2 (cdr p1)) (cdr p2)))
             (n (max 1 (exact (ceiling (sqrt (/ (sqrt (dist2 ddx ddy))
                                               (* 8 tolerance))))))))
        (let loop ((i 1) (acc '()))
          (if (> i n)
              (reverse acc)
              (let* ((t (/ i (inexact n))) (u (- 1.0 t)))
                (loop (+ i 1)
                      (cons (cons (+ (* u u (car p0)) (* 2 u t (car p1)) (* t t (car p2)))
                                  (+ (* u u (cdr p0)) (* 2 u t (cdr p1)) (* t t (cdr p2))))
                            acc)))))))

    (define (flatten-cubic p0 p1 p2 p3)
      (let* ((d1 (dist2 (+ (car p0) (* -2 (car p1)) (car p2))
                        (+ (cdr p0) (* -2 (cdr p1)) (cdr p2))))
             (d2 (dist2 (+ (car p1) (* -2 (car p2)) (car p3))
                        (+ (cdr p1) (* -2 (cdr p2)) (cdr p3))))
             (dd (sqrt (max d1 d2)))
             (n (max 1 (exact (ceiling (sqrt (/ (* 3 dd) (* 4 tolerance))))))))
        (let loop ((i 1) (acc '()))
          (if (> i n)
              (reverse acc)
              (let* ((t (/ i (inexact n))) (u (- 1.0 t))
                     (a (* u u u)) (b (* 3 u u t)) (c (* 3 u t t)) (d (* t t t)))
                (loop (+ i 1)
                      (cons (cons (+ (* a (car p0)) (* b (car p1)) (* c (car p2)) (* d (car p3)))
                                  (+ (* a (cdr p0)) (* b (cdr p1)) (* c (cdr p2)) (* d (cdr p3))))
                            acc)))))))

    ;; --- coverage -----------------------------------------------------

    ;; Adds the signed area of the edge (x0, y0) -> (x1, y1) to acc, a
    ;; w x h buffer whose pixel (0, 0) is at device (ox, oy). The edge is
    ;; clipped to the buffer vertically; horizontally the box always
    ;; contains it.
    (define (accumulate-edge! acc w h ox oy x0 y0 x1 y1)
      (let ((x0 (- x0 ox)) (y0 (- y0 oy)) (x1 (- x1 ox)) (y1 (- y1 oy)))
        (unless (< (abs (- y0 y1)) 1e-9)
          (let-values (((dir px0 py0 px1 py1)
                        (if (< y0 y1)
                            (values 1.0 x0 y0 x1 y1)
                            (values -1.0 x1 y1 x0 y0))))
            (let* ((dxdy (/ (- px1 px0) (- py1 py0)))
                   (x (if (< py0 0.0) (- px0 (* py0 dxdy)) px0))
                   (ystart (max 0 (exact (floor py0))))
                   (yend (min h (exact (ceiling py1)))))
              (let row ((yy ystart) (x x))
                (when (< yy yend)
                  (let* ((ls (* yy w))
                         (dy (- (min (+ yy 1.0) py1) (max (inexact yy) py0)))
                         (xnext (+ x (* dxdy dy)))
                         (d (* dy dir))
                         (xa (min x xnext)) (xb (max x xnext))
                         (xaf (floor xa)) (xai (exact xaf))
                         (xbc (ceiling xb)) (xbi (exact xbc)))
                    (define (add! k v) (vector-set! acc k (+ (vector-ref acc k) v)))
                    (if (<= xbi (+ xai 1))
                        ;; within one pixel column
                        (let ((xmf (- (* 0.5 (+ x xnext)) xaf))
                              (k (+ ls xai)))
                          (add! k (- d (* d xmf)))
                          (add! (+ k 1) (* d xmf)))
                        (let* ((s (/ 1.0 (- xb xa)))
                               (x0f (- xa xaf))
                               (a0 (* 0.5 s (- 1.0 x0f) (- 1.0 x0f)))
                               (x1f (+ (- xb xbc) 1.0))
                               (am (* 0.5 s x1f x1f))
                               (k (+ ls xai)))
                          (add! k (* d a0))
                          (if (= xbi (+ xai 2))
                              (add! (+ k 1) (* d (- 1.0 a0 am)))
                              (let ((a1 (* s (- 1.5 x0f))))
                                (add! (+ k 1) (* d (- a1 a0)))
                                (do ((xi (+ xai 2) (+ xi 1))) ((>= xi (- xbi 1)))
                                  (add! (+ ls xi) (* d s)))
                                (let ((a2 (+ a1 (* (- xbi xai 3) s))))
                                  (add! (+ ls (- xbi 1)) (* d (- 1.0 a2 am))))))
                          (add! (+ ls xbi) (* d am))))
                    (row (+ yy 1) xnext)))))))))

    ;; Fills rings (lists of (x . y), implicitly closed) with paint.
    ;; rule: 'nonzero or 'evenodd; opacity multiplies the paint's alpha.
    (define (fill-rings! canvas rings rule paint opacity)
      (let ((W (canvas-width canvas)) (H (canvas-height canvas)))
        (let bounds ((rs rings) (x0 +inf.0) (y0 +inf.0) (x1 -inf.0) (y1 -inf.0))
          (if (pair? rs)
              (let pts ((ps (car rs)) (x0 x0) (y0 y0) (x1 x1) (y1 y1))
                (if (pair? ps)
                    (let ((x (caar ps)) (y (cdar ps)))
                      (pts (cdr ps) (min x0 x) (min y0 y) (max x1 x) (max y1 y)))
                    (bounds (cdr rs) x0 y0 x1 y1)))
              (when (and (< x0 x1) (< y0 y1))
                (let* ((bx0 (max 0 (exact (floor x0))))
                       (by0 (max 0 (exact (floor y0))))
                       (bx1 (min W (exact (ceiling x1))))
                       (by1 (min H (exact (ceiling y1))))
                       ;; the edges are clipped vertically only, so the
                       ;; buffer spans their full width, plus the column
                       ;; right of the last that the algorithm writes to
                       (ox (exact (floor x0)))
                       (w (+ (- (exact (ceiling x1)) ox) 2))
                       (h (- by1 by0)))
                  (when (and (> h 0) (< bx0 bx1))
                    (let ((acc (make-vector (* w h) 0.0)))
                      (for-each
                       (lambda (ring)
                         (let loop ((p ring))
                           (when (pair? p)
                             (let ((a (car p)) (b (if (pair? (cdr p)) (cadr p) (car ring))))
                               (accumulate-edge! acc w h ox by0 (car a) (cdr a) (car b) (cdr b))
                               (loop (cdr p))))))
                       rings)
                      (composite! canvas acc w h ox by0 bx0 bx1 rule paint opacity)))))))))

    ;; Sums each row of acc into coverage and blends paint over the
    ;; canvas where the coverage is positive, columns bx0 .. bx1-1. The
    ;; hot loop of the library. Between edges acc is zero and the
    ;; coverage constant, so such a run is handled at once: skipped when
    ;; uncovered, copied from a row of the paint when fully covered by
    ;; an opaque colour, and blended pixel by pixel only otherwise.
    (define (composite! canvas acc w h ox oy bx0 bx1 rule paint opacity)
      (let* ((W (canvas-width canvas)) (px (canvas-pixels canvas))
             (solid? (vector? paint))
             (evenodd? (eq? rule 'evenodd))
             (r (if solid? (vector-ref paint 0) 0))
             (g (if solid? (vector-ref paint 1) 0))
             (b (if solid? (vector-ref paint 2) 0))
             (pa (if solid? (* opacity (vector-ref paint 3)) opacity))
             (i0 (- bx0 ox))
             (i1 (- bx1 ox))
             (template (and solid? (>= pa 0.999)
                            (let ((t (make-bytevector (* 4 (- bx1 bx0)) 255)))
                              (do ((k 0 (+ k 4))) ((= k (bytevector-length t)) t)
                                (bytevector-u8-set! t k r)
                                (bytevector-u8-set! t (+ k 1) g)
                                (bytevector-u8-set! t (+ k 2) b))))))
        (define (coverage sum)
          (let ((a (abs sum)))
            (if evenodd?
                (let ((m (- a (* 2.0 (floor (* a 0.5))))))
                  (if (> m 1.0) (- 2.0 m) m))
                (if (> a 1.0) 1.0 a))))
        (do ((yy 0 (+ yy 1))) ((= yy h))
          (let* ((ls (* yy w)) (y (+ oy yy)) (rowk (* 4 (+ (* y W) ox))))
            (define (paint-pixel! i cov)
              (let ((k (+ rowk (* 4 i))))
                (if solid?
                    (put! px k r g b (* cov pa))
                    (let ((c (paint (+ ox i 0.5) (+ y 0.5))))
                      (put! px k (vector-ref c 0) (vector-ref c 1) (vector-ref c 2)
                            (* cov opacity (vector-ref c 3)))))))
            (let col ((i 0) (sum 0.0))
              (when (< i i1)
                (let* ((sum (+ sum (vector-ref acc (+ ls i))))
                       ;; the run of columns after i with nothing added
                       (j (let scan ((j (+ i 1)))
                            (if (and (< j i1) (= 0.0 (vector-ref acc (+ ls j))))
                                (scan (+ j 1))
                                j)))
                       (cov (coverage sum))
                       (from (max i i0)))
                  (when (and (> cov 0.001) (< from j))
                    (if (and template (>= cov 0.999))
                        (bytevector-copy! px (+ rowk (* 4 from)) template 0 (* 4 (- j from)))
                        (do ((k from (+ k 1))) ((= k j))
                          (paint-pixel! k cov))))
                  (col j sum))))))))

    (define (to-byte v) (exact (floor (+ v 0.5))))

    ;; Source over, straight alpha, sa the source alpha after coverage.
    (define (put! px k r g b sa)
      (cond
       ((<= sa 0.0) #f)
       ((>= sa 0.999)
        (bytevector-u8-set! px k r)
        (bytevector-u8-set! px (+ k 1) g)
        (bytevector-u8-set! px (+ k 2) b)
        (bytevector-u8-set! px (+ k 3) 255))
       (else
        (let ((dab (bytevector-u8-ref px (+ k 3)))
              (ia (- 1.0 sa)))
          (if (= dab 255)
              (begin
                (bytevector-u8-set! px k (to-byte (+ (* r sa) (* (bytevector-u8-ref px k) ia))))
                (bytevector-u8-set! px (+ k 1) (to-byte (+ (* g sa) (* (bytevector-u8-ref px (+ k 1)) ia))))
                (bytevector-u8-set! px (+ k 2) (to-byte (+ (* b sa) (* (bytevector-u8-ref px (+ k 2)) ia)))))
              (let* ((da (/ dab 255.0))
                     (dw (* da ia))
                     (oa (+ sa dw)))
                (bytevector-u8-set! px k (to-byte (/ (+ (* r sa) (* (bytevector-u8-ref px k) dw)) oa)))
                (bytevector-u8-set! px (+ k 1) (to-byte (/ (+ (* g sa) (* (bytevector-u8-ref px (+ k 1)) dw)) oa)))
                (bytevector-u8-set! px (+ k 2) (to-byte (/ (+ (* b sa) (* (bytevector-u8-ref px (+ k 2)) dw)) oa)))
                (bytevector-u8-set! px (+ k 3) (to-byte (* 255.0 oa)))))))))

    ;; --- options --------------------------------------------------------

    (define (opt options key default)
      (let ((p (assq key options))) (if p (cdr p) default)))

    ;; --- fill -----------------------------------------------------------

    (define (canvas-fill-path! canvas path paint . options)
      "Syntax: (canvas-fill-path! canvas path paint [options])
Library: (scm raster)
Description: Fills path with paint, anti-aliased. paint is a colour from
  rgba, or a procedure (lambda (x y) ...) returning one for the pixel
  centre x, y (for gradients and patterns). options is an alist:
  (transform . m) applies the transform m to the path; (fill-rule .
  evenodd) or (fill-rule . nonzero), the default; (opacity . a)
  multiplies the paint's alpha by a.
Example:
  (canvas-fill-path! c (path-circle 50 50 20) (rgba 200 0 0))
  (canvas-fill-path! c path (rgba 0 0 0) '((fill-rule . evenodd)))"
      (let* ((options (if (pair? options) (car options) '()))
             (m (opt options 'transform (transform-identity)))
             (rings (map cdr (flatten path m))))
        (fill-rings! canvas rings (opt options 'fill-rule 'nonzero) paint
                     (inexact (opt options 'opacity 1.0)))))

    ;; --- stroke ---------------------------------------------------------

    (define pi (* 4 (atan 1)))

    (define (signed-area ring)
      (let loop ((p ring) (s 0.0))
        (if (null? p)
            s
            (let ((a (car p)) (b (if (pair? (cdr p)) (cadr p) (car ring))))
              (loop (cdr p) (+ s (- (* (car a) (cdr b)) (* (car b) (cdr a)))))))))

    ;; Every stroke piece is wound the same way, so their coverage adds up
    ;; instead of cancelling, and the non-zero clamp makes it a union.
    (define (positive ring) (if (< (signed-area ring) 0) (reverse ring) ring))

    (define (disc cx cy r)
      (let ((n (max 8 (exact (ceiling (/ (* 2 pi r) 1.0))))))
        (let loop ((i 0) (acc '()))
          (if (= i n)
              acc
              (let ((t (/ (* 2 pi i) n)))
                (loop (+ i 1) (cons (cons (+ cx (* r (cos t))) (+ cy (* r (sin t)))) acc)))))))

    ;; consecutive duplicates removed
    (define (dedupe pts)
      (let loop ((ps pts) (acc '()))
        (cond ((null? ps) (reverse acc))
              ((and (pair? acc)
                    (< (dist2 (- (caar ps) (caar acc)) (- (cdar ps) (cdar acc))) 1e-12))
               (loop (cdr ps) acc))
              (else (loop (cdr ps) (cons (car ps) acc))))))

    (define (unit a b)
      (let* ((dx (- (car b) (car a))) (dy (- (cdr b) (cdr a)))
             (l (sqrt (dist2 dx dy))))
        (cons (/ dx l) (/ dy l))))

    ;; The polygons that make up the stroke of one polyline.
    (define (stroke-polyline pts closed? hw join cap miter-limit)
      (let* ((pts (dedupe pts))
             (pts (if (and closed? (pair? pts) (pair? (cdr pts))
                           (< (dist2 (- (caar pts) (car (last pts)))
                                     (- (cdar pts) (cdr (last pts))))
                              1e-12))
                      (except-last pts)
                      pts)))
        (cond
         ((null? pts) '())
         ((null? (cdr pts))
          ;; a single point: only a round or square cap shows
          (let ((x (caar pts)) (y (cdar pts)))
            (case cap
              ((round) (list (disc x y hw)))
              ((square) (list (list (cons (- x hw) (- y hw)) (cons (+ x hw) (- y hw))
                                    (cons (+ x hw) (+ y hw)) (cons (- x hw) (+ y hw)))))
              (else '()))))
         (else
          (let* ((ring (if closed? (append pts (list (car pts))) pts))
                 (ring (if (and (not closed?) (eq? cap 'square)) (extend-ends ring hw) ring))
                 (segs (let loop ((p ring) (acc '()))
                         (if (null? (cdr p))
                             acc
                             (loop (cdr p)
                                   (cons (segment-quad (car p) (cadr p) hw) acc)))))
                 (joins (join-polys ring closed? hw join miter-limit))
                 (caps (if (and (not closed?) (eq? cap 'round))
                           (list (disc (caar ring) (cdar ring) hw)
                                 (let ((e (last ring))) (disc (car e) (cdr e) hw)))
                           '())))
            (append segs joins caps))))))

    (define (last l) (if (null? (cdr l)) (car l) (last (cdr l))))
    (define (except-last l) (if (null? (cdr l)) '() (cons (car l) (except-last (cdr l)))))

    (define (segment-quad a b hw)
      (let* ((u (unit a b)) (nx (* hw (- (cdr u)))) (ny (* hw (car u))))
        (list (cons (+ (car a) nx) (+ (cdr a) ny)) (cons (+ (car b) nx) (+ (cdr b) ny))
              (cons (- (car b) nx) (- (cdr b) ny)) (cons (- (car a) nx) (- (cdr a) ny)))))

    ;; square caps: each end pushed out by half the width
    (define (extend-ends pts hw)
      (let* ((u0 (unit (cadr pts) (car pts)))
             (n (length pts))
             (e (list-ref pts (- n 1))) (pe (list-ref pts (- n 2)))
             (u1 (unit pe e))
             (first (cons (+ (caar pts) (* hw (car u0))) (+ (cdar pts) (* hw (cdr u0)))))
             (lastp (cons (+ (car e) (* hw (car u1))) (+ (cdr e) (* hw (cdr u1))))))
        (append (list first) (except-last (cdr pts)) (list lastp))))

    ;; At each vertex where two segments meet (and where a closed one
    ;; closes), the gap on the outer side of the turn.
    (define (join-polys ring closed? hw join miter-limit)
      (let ((v (list->vector ring)))
        (let ((n (vector-length v)))
          (let loop ((i 1) (acc '()))
            (if (>= i (- n 1))
                (if (and closed? (> n 2))
                    (append (join-at (vector-ref v (- n 2)) (vector-ref v 0) (vector-ref v 1)
                                     hw join miter-limit)
                            acc)
                    acc)
                (loop (+ i 1)
                      (append (join-at (vector-ref v (- i 1)) (vector-ref v i) (vector-ref v (+ i 1))
                                       hw join miter-limit)
                              acc)))))))

    (define (join-at a v b hw join miter-limit)
      (let* ((d1 (unit a v)) (d2 (unit v b))
             (cross (- (* (car d1) (cdr d2)) (* (cdr d1) (car d2))))
             (dot (+ (* (car d1) (car d2)) (* (cdr d1) (cdr d2)))))
        (cond
         ;; straight on: the quads already meet
         ((and (< (abs cross) 1e-9) (> dot 0)) '())
         ((eq? join 'round) (list (disc (car v) (cdr v) hw)))
         (else
          (let* ((s (if (> cross 0) -1.0 1.0))
                 (n1x (- (cdr d1))) (n1y (car d1))
                 (n2x (- (cdr d2))) (n2y (car d2))
                 (p1 (cons (+ (car v) (* s hw n1x)) (+ (cdr v) (* s hw n1y))))
                 (p2 (cons (+ (car v) (* s hw n2x)) (+ (cdr v) (* s hw n2y))))
                 (ndot (+ (* n1x n2x) (* n1y n2y)))
                 (bevel (list v p1 p2)))
            (if (and (eq? join 'miter) (> (+ 1.0 ndot) 1e-9)
                     ;; the miter's length over half the width is 2/|n1+n2|
                     (<= (/ 2.0 (sqrt (* 2.0 (+ 1.0 ndot)))) miter-limit))
                (let ((k (/ (* s hw) (+ 1.0 ndot))))
                  (list (list v p1 (cons (+ (car v) (* k (+ n1x n2x)))
                                         (+ (cdr v) (* k (+ n1y n2y))))
                              p2)))
                (list bevel)))))))

    ;; Cuts a polyline into the dashes of pattern (lengths, on, off, ...)
    ;; starting offset into it. -> list of point lists.
    (define (dash-polyline pts pattern offset)
      (let* ((pat (list->vector pattern))
             (np (vector-length pat))
             (total (let loop ((i 0) (s 0.0)) (if (= i np) s (loop (+ i 1) (+ s (vector-ref pat i)))))))
        (if (<= total 0)
            (list pts)
            ;; find where in the pattern the offset lands
            (let start ((i 0) (left (let ((o (- offset (* total (floor (/ offset total)))))) o)))
              (if (> left (vector-ref pat i))
                  (start (modulo (+ i 1) np) (- left (vector-ref pat i)))
                  (let walk ((ps pts) (i i) (remain (- (vector-ref pat i) left))
                             (cur (if (even? i) (list (car pts)) '())) (out '()))
                    (if (null? (cdr ps))
                        (reverse (if (and (even? i) (pair? (cdr* cur))) (cons (reverse cur) out) out))
                        (let* ((a (car ps)) (b (cadr ps))
                               (seg (sqrt (dist2 (- (car b) (car a)) (- (cdr b) (cdr a))))))
                          (if (< remain seg)
                              ;; the pattern switches inside this segment
                              (let* ((t (/ remain seg))
                                     (p (cons (+ (car a) (* t (- (car b) (car a))))
                                              (+ (cdr a) (* t (- (cdr b) (cdr a))))))
                                     (next (modulo (+ i 1) np)))
                                (if (even? i)
                                    (walk (cons p (cdr ps)) next (vector-ref pat next)
                                          '() (cons (reverse (cons p cur)) out))
                                    (walk (cons p (cdr ps)) next (vector-ref pat next)
                                          (list p) out)))
                              (walk (cdr ps) i (- remain seg)
                                    (if (even? i) (cons b cur) cur) out))))))))))

    (define (cdr* l) (if (pair? l) (cdr l) '()))

    (define (canvas-stroke-path! canvas path paint . options)
      "Syntax: (canvas-stroke-path! canvas path paint [options])
Library: (scm raster)
Description: Strokes path with paint, anti-aliased. options is an alist:
  (width . w), default 1; (join . miter|round|bevel), default miter;
  (cap . butt|round|square), default butt; (miter-limit . l), default 4;
  (dash . (on off ...)) and (dash-offset . o) for dashed lines;
  (transform . m), which also scales the width; (opacity . a).
Example:
  (canvas-stroke-path! c '((M 10 10) (L 90 90)) (rgba 0 0 0)
                       '((width . 2) (cap . round)))"
      (let* ((options (if (pair? options) (car options) '()))
             (m (opt options 'transform (transform-identity)))
             (hw (* 0.5 (inexact (opt options 'width 1)) (transform-scale-factor m)))
             (join (opt options 'join 'miter))
             (cap (opt options 'cap 'butt))
             (limit (inexact (opt options 'miter-limit 4)))
             (dash (let ((d (opt options 'dash #f)))
                     (and d (pair? d) (positive-pattern d)
                          (map (lambda (x) (* (inexact x) (transform-scale-factor m))) d))))
             (offset (* (inexact (opt options 'dash-offset 0)) (transform-scale-factor m)))
             (subpaths (flatten path m))
             (polys
              (apply append
                     (map (lambda (sp)
                            (let ((closed? (car sp)) (pts (cdr sp)))
                              (if dash
                                  (apply append
                                         (map (lambda (piece)
                                                (stroke-polyline piece #f hw join cap limit))
                                              (dash-polyline (if closed? (append pts (list (car pts))) pts)
                                                             (if (odd? (length dash)) (append dash dash) dash)
                                                             offset)))
                                  (stroke-polyline pts closed? hw join cap limit))))
                          subpaths))))
        (when (> hw 0)
          (fill-rings! canvas (map positive polys) 'nonzero paint
                       (inexact (opt options 'opacity 1.0))))))

    (define (positive-pattern d)
      (let loop ((d d) (any #f))
        (cond ((null? d) any)
              ((< (car d) 0) #f)
              (else (loop (cdr d) (or any (> (car d) 0)))))))

))
