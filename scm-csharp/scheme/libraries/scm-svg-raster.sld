;; (scm svg raster) — renders SVG to a (scm raster) canvas or a PNG.
;;
;; Takes SVG text, or the SXML tree (scm html builder) renders, so a
;; program that builds its SVG as SXML can skip the round trip through
;; text. Supported, as a reasonable subset of SVG 1.1:
;;
;;   elements    svg (also nested), g, a, defs, use, rect, circle, ellipse,
;;               line, polyline, polygon, path (all commands, arcs too),
;;               text and tspan (one line each), pattern, style
;;   styling     presentation attributes, the style attribute, and <style>
;;               sheets with type, class and id selectors, descendant
;;               combinators, specificity and source order; rules inside
;;               @-blocks (@media) and selectors with pseudo-classes,
;;               attribute selectors or other combinators are skipped
;;   properties  fill, stroke (colours, none, url(#pattern)), opacity,
;;               fill-opacity, stroke-opacity, fill-rule, stroke-width,
;;               stroke-linejoin, stroke-linecap, stroke-miterlimit,
;;               stroke-dasharray, stroke-dashoffset, font-size,
;;               font-weight, text-anchor, paint-order, display,
;;               visibility, transform
;;
;; Not supported: gradients, clipping, masks, filters, images, markers,
;; text layout beyond one line per text element. Group opacity is
;; applied to each shape in the group rather than to the group as a
;; whole. Text is set in DejaVu Sans, or the fonts passed in.

(define-library (scm svg raster)
  (export svg->canvas
          svg->png
          svg-text->sxml)
  (import (scheme base)
          (scheme char)
          (scheme inexact)
          (scheme cxr)
          (srfi 1)
          (srfi 13)
          (only (srfi 69) make-hash-table hash-table-set! hash-table-ref/default)
          (scm html builder)
          (scm raster)
          (scm svg core)
          (scm truetype)
          (scm fonts dejavu))
  (begin

    ;; --- rendering ---------------------------------------------------------

    ;; ctx: the state while walking the tree
    (define-record-type ctx
      (make-ctx canvas rules ids fonts opacity)
      ctx?
      (canvas ctx-canvas)
      (rules ctx-rules)
      (ids ctx-ids)
      (fonts ctx-fonts)
      (opacity ctx-opacity))

    (define (with-opacity c o)
      (make-ctx (ctx-canvas c) (ctx-rules c) (ctx-ids c) (ctx-fonts c) o))

    (define (render-node c node m style ancestors)
      (when (element? node)
        (let* ((tag (car node))
               (st (compute-style node style (ctx-rules c) ancestors))
               (m (let ((t (attr node 'transform)))
                    (if t (transform-multiply m (parse-transform t)) m)))
               (o (* (ctx-opacity c) (number-or (prop st "opacity") 1.0)))
               (c (with-opacity c o))
               (anc (cons (element-info node) ancestors)))
          (unless (equal? (prop st "display") "none")
            (case tag
              ((g a) (for-each (lambda (k) (render-node c k m st anc)) (el-children node)))
              ((svg) (render-nested-svg c node m st anc))
              ((use) (render-use c node m st anc))
              ((rect circle ellipse line polyline polygon path)
               (draw-shape c (shape-path node) m st (not (memq tag '(line)))))
              ((text) (draw-text c node m st))
              (else #f))))))

    (define (render-nested-svg c node m st anc)
      (let* ((x (length-attr node 'x 0)) (y (length-attr node 'y 0))
             (m (transform-multiply m (transform-multiply (transform-translate x y)
                                                          (viewbox-transform node #f #f)))))
        (for-each (lambda (k) (render-node c k m st anc)) (el-children node))))

    (define (render-use c node m st anc)
      (let* ((href (or (attr node 'href) (attr node 'xlink:href)))
             (entry (and href (string-prefix? "#" href)
                         (hash-table-ref/default (ctx-ids c) (substring href 1 (string-length href)) #f)))
             (target (and entry (car entry))))
        (when (and target (not (eq? (car target) 'use)))
          (render-node c target
                       (transform-multiply m (transform-translate (length-attr node 'x 0)
                                                                  (length-attr node 'y 0)))
                       st anc))))

    ;; resolves a paint property to what (scm raster) takes, or #f
    (define (paint-for c st name opacity-name m)
      (let ((p (parse-paint (or (prop st name) "none")))
            (a (* (ctx-opacity c) (number-or (prop st opacity-name) 1.0))))
        (cond
         ((or (not p) (eq? p 'none) (<= a 0)) #f)
         ((vector? p) (with-alpha p a))
         ((pair? p)
          (let ((entry (hash-table-ref/default (ctx-ids c) (cdr p) #f)))
            (and entry (eq? (car (car entry)) 'pattern)
                 (pattern-paint c (car entry) (cdr entry) m a))))
         (else #f))))

    (define (draw-shape c path m st fill?)
      (unless (or (null? path) (equal? (prop st "visibility") "hidden"))
        (let ((fill (and fill? (paint-for c st "fill" "fill-opacity" m)))
              (stroke (paint-for c st "stroke" "stroke-opacity" m))
              (stroke-first? (let ((po (prop st "paint-order")))
                               (and po (string-prefix? "stroke" (string-trim-both po))))))
          (define (do-fill)
            (when fill
              (canvas-fill-path! (ctx-canvas c) path fill
                                 `((transform . ,m)
                                   (fill-rule . ,(if (equal? (prop st "fill-rule") "evenodd")
                                                     'evenodd 'nonzero))))))
          (define (do-stroke)
            (when stroke
              (let ((w (number-or (prop st "stroke-width") 1)))
                (when (> w 0)
                  (canvas-stroke-path! (ctx-canvas c) path stroke (stroke-options st m w))))))
          (if stroke-first?
              (begin (do-stroke) (do-fill))
              (begin (do-fill) (do-stroke))))))

    (define (stroke-options st m w)
      (let ((join (prop st "stroke-linejoin"))
            (cap (prop st "stroke-linecap"))
            (dash (let ((d (prop st "stroke-dasharray")))
                    (and d (not (string=? (string-trim-both d) "none"))
                         (let ((ns (numbers d))) (and (pair? ns) ns))))))
        `((transform . ,m) (width . ,w)
          (join . ,(cond ((equal? join "round") 'round) ((equal? join "bevel") 'bevel) (else 'miter)))
          (cap . ,(cond ((equal? cap "round") 'round) ((equal? cap "square") 'square) (else 'butt)))
          (miter-limit . ,(number-or (prop st "stroke-miterlimit") 4))
          ,@(if dash
                `((dash . ,dash) (dash-offset . ,(number-or (prop st "stroke-dashoffset") 0)))
                '()))))

    ;; One line of text per element: tspans are part of the text, not
    ;; positioned on their own. Whitespace collapses as in SVG.
    (define (draw-text c node m st)
      (let* ((text (collapse-spaces (node-text node)))
             (size (number-or (prop st "font-size") 16))
             (weight (prop st "font-weight"))
             (bold? (or (member weight '("bold" "bolder"))
                        (>= (number-or weight 400) 600)))
             (font (cdr (or (assq (if bold? 'bold 'normal) (ctx-fonts c))
                            (assq 'normal (ctx-fonts c)))))
             (x (let ((v (attr node 'x))) (if v (let ((ns (numbers v))) (if (pair? ns) (car ns) 0)) 0)))
             (y (let ((v (attr node 'y))) (if v (let ((ns (numbers v))) (if (pair? ns) (car ns) 0)) 0)))
             (anchor (prop st "text-anchor"))
             (w (font-text-width font size text))
             (x (cond ((equal? anchor "middle") (- x (/ w 2)))
                      ((equal? anchor "end") (- x w))
                      (else x))))
        (unless (string-null? text)
          ;; a stroke around text (a halo) looks right only with round joins
          (draw-shape c (font-text-path font size x y text) m
                      (if (assoc "stroke-linejoin" st) st (cons '("stroke-linejoin" . "round") st))
                      #t))))

    ;; A pattern (patternUnits userSpaceOnUse, as user space is assumed in
    ;; any case) is rendered once into a tile at device resolution and
    ;; sampled through the inverse of the transform it is painted with.
    (define (pattern-paint c pat ancestors m alpha)
      (let* ((pw (length-attr pat 'width 0)) (ph (length-attr pat 'height 0))
             (px (length-attr pat 'x 0)) (py (length-attr pat 'y 0)))
        (and (> pw 0) (> ph 0)
             (let* ((pm (transform-multiply
                         m (transform-multiply
                            (let ((t (attr pat 'patternTransform))) (if t (parse-transform t) (transform-identity)))
                            (transform-translate px py))))
                    (s (max 0.01 (scale-factor pm)))
                    (tw (max 1 (min 512 (exact (ceiling (* pw s))))))
                    (th (max 1 (min 512 (exact (ceiling (* ph s))))))
                    (sx (/ tw pw)) (sy (/ th ph))
                    (tile (make-canvas tw th))
                    (tc (make-ctx tile (ctx-rules c) (ctx-ids c) (ctx-fonts c) 1.0))
                    (st (compute-style pat '() (ctx-rules c) ancestors))
                    (anc (cons (element-info pat) ancestors))
                    (inv (invert pm))
                    (px (canvas-pixels tile)))
               (for-each (lambda (k) (render-node tc k (transform-scale sx sy) st anc))
                         (el-children pat))
               (lambda (x y)
                 (let* ((u (+ (* (vector-ref inv 0) x) (* (vector-ref inv 2) y) (vector-ref inv 4)))
                        (v (+ (* (vector-ref inv 1) x) (* (vector-ref inv 3) y) (vector-ref inv 5)))
                        (u (- u (* pw (floor (/ u pw)))))
                        (v (- v (* ph (floor (/ v ph)))))
                        (i (min (- tw 1) (exact (floor (* u sx)))))
                        (j (min (- th 1) (exact (floor (* v sy)))))
                        (k (* 4 (+ i (* j tw)))))
                   (vector (bytevector-u8-ref px k) (bytevector-u8-ref px (+ k 1))
                           (bytevector-u8-ref px (+ k 2))
                           (* alpha (/ (bytevector-u8-ref px (+ k 3)) 255.0)))))))))

    ;; --- entry points -------------------------------------------------------

    (define (svg->canvas svg . options)
      "Syntax: (svg->canvas svg [options])
Library: (scm svg raster)
Description: Renders svg, SVG text or an SXML tree (as (scm html builder)
  takes it), to a new canvas of (scm raster) and returns it. The canvas
  is the root's width and height (or its viewBox's size) times the scale.
  options is an alist: (scale . s), default 1; (background . colour), a
  colour from rgba, transparent by default; (fonts . ((normal . font)
  (bold . font))), fonts of (scm truetype), DejaVu Sans by default.
Example:
  (svg->canvas \"<svg width='20' height='20'><circle cx='10' cy='10' r='8'/></svg>\"
               '((scale . 2)))"
      (let* ((options (if (pair? options) (car options) '()))
             (root (if (string? svg) (svg-text->sxml svg) svg))
             (scale (inexact (option options 'scale 1)))
             (vb (let ((v (attr root 'viewBox))) (and v (numbers v))))
             (w (length-attr root 'width (if (and vb (= (length vb) 4)) (caddr vb) 300)))
             (h (length-attr root 'height (if (and vb (= (length vb) 4)) (cadddr vb) 150)))
             (canvas (let ((bg (option options 'background #f))
                           (cw (max 1 (exact (ceiling (* w scale)))))
                           (ch (max 1 (exact (ceiling (* h scale))))))
                       (if bg (make-canvas cw ch bg) (make-canvas cw ch))))
             (rules (list '()))
             (ids (make-hash-table equal?)))
        (collect root rules ids '())
        ;; the root's children, through its viewBox and the scale
        (let* ((c (make-ctx canvas (car rules) ids
                            (option options 'fonts
                                    (list (cons 'normal dejavu-sans) (cons 'bold dejavu-sans-bold)))
                            1.0))
               (st (compute-style root '() (car rules) '()))
               (m (transform-multiply (transform-scale scale) (viewbox-transform root w h)))
               (c (with-opacity c (number-or (prop st "opacity") 1.0)))
               (anc (list (element-info root))))
          (unless (equal? (prop st "display") "none")
            (for-each (lambda (k) (render-node c k m st anc)) (el-children root))))
        canvas))

    (define (svg->png svg . options)
      "Syntax: (svg->png svg [options])
Library: (scm svg raster)
Description: Renders svg like svg->canvas and returns it encoded as a PNG
  bytevector.
Example:
  (svg->png chart-sxml '((scale . 2) (background . #(255 255 255 1.0))))"
      (canvas->png (apply svg->canvas svg options)))

))
