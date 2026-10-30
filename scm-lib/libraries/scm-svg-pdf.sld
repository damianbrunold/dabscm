;; (scm svg pdf) — draws SVG on a page of (scm pdf), as vectors: paths
;; stay paths and text stays text (in an embedded font), so the result
;; scales and its text can be searched and copied.
;;
;; The same subset of SVG as (scm svg raster) — see there — through the
;; same parser and style cascade, (scm svg core); patterns are not drawn
;; (their shapes are left unfilled). Text is set in DejaVu Sans, or the
;; fonts passed in, embedded once per document.

(define-library (scm svg pdf)
  (export svg->pdf-page!
          svg->pdf
          svg-size
          svg-pdf-font)
  (import (scheme base)
          (scheme inexact)
          (scheme cxr)
          (srfi 1)
          (srfi 13)
          (only (srfi 69) make-hash-table hash-table-ref/default)
          (scm raster)
          (scm truetype)
          (scm fonts dejavu)
          (scm pdf)
          (scm svg core))
  (begin

    ;; ctx: the state while walking the tree
    (define-record-type ctx
      (make-ctx doc page rules ids fonts opacity)
      ctx?
      (doc ctx-doc)
      (page ctx-page)
      (rules ctx-rules)
      (ids ctx-ids)
      (fonts ctx-fonts)        ; alist weight -> (truetype-font . pdf-font-or-#f), shared
      (opacity ctx-opacity))

    (define (with-opacity c o)
      (make-ctx (ctx-doc c) (ctx-page c) (ctx-rules c) (ctx-ids c) (ctx-fonts c) o))

    ;; Fonts are embedded on first use, once per document and font: the
    ;; documents seen so far, each with an alist font -> pdf font.
    (define embedded '())

    (define (svg-pdf-font doc font)
      "Syntax: (svg-pdf-font doc font)
Library: (scm svg pdf)
Description: The PDF font of doc for font, a font of (scm truetype),
  embedded on first use and shared with the SVG drawn on doc, so a page
  that adds its own text in the same font embeds it only once.
Example:
  (pdf-draw-text page (svg-pdf-font doc dejavu-sans) 10 50 700 \"Hello\")"
      (let* ((entry (or (assq doc embedded)
                        (let ((e (list doc)))
                          (set! embedded (cons e (if (> (length embedded) 16) (take embedded 16) embedded)))
                          e)))
             (hit (assq font (cdr entry))))
        (if hit
            (cdr hit)
            (let ((pf (pdf-embed-truetype-font doc (font->truetype font "Embedded")
                                               (string-append "DabscmFont" (number->string (length (cdr entry)))))))
              (set-cdr! entry (cons (cons font pf) (cdr entry)))
              pf))))

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

    ;; a solid colour with its alpha, or #f (none, patterns, unknown)
    (define (paint-for c st name opacity-name)
      (let ((p (parse-paint (or (prop st name) "none")))
            (a (* (ctx-opacity c) (number-or (prop st opacity-name) 1.0))))
        (and (vector? p) (> a 0) (with-alpha p a))))

    (define (emit-path! page path)
      (let loop ((cs path) (x 0.0) (y 0.0))
        (unless (null? cs)
          (let ((cmd (car cs)))
            (case (car cmd)
              ((M) (pdf-move-to page (cadr cmd) (caddr cmd)) (loop (cdr cs) (cadr cmd) (caddr cmd)))
              ((L) (pdf-line-to page (cadr cmd) (caddr cmd)) (loop (cdr cs) (cadr cmd) (caddr cmd)))
              ((Q)
               ;; quadratic -> cubic: control points 2/3 of the way to the quadratic one
               (let ((qx (list-ref cmd 1)) (qy (list-ref cmd 2)) (ex (list-ref cmd 3)) (ey (list-ref cmd 4)))
                 (pdf-curve-to page (+ x (* 2/3 (- qx x))) (+ y (* 2/3 (- qy y)))
                               (+ ex (* 2/3 (- qx ex))) (+ ey (* 2/3 (- qy ey))) ex ey)
                 (loop (cdr cs) ex ey)))
              ((C)
               (apply pdf-curve-to page (cdr cmd))
               (loop (cdr cs) (list-ref cmd 5) (list-ref cmd 6)))
              ((Z) (pdf-close-path page) (loop (cdr cs) x y))
              (else (loop (cdr cs) x y)))))))

    (define (set-colour! page setter colour)
      (setter page (/ (vector-ref colour 0) 255.0) (/ (vector-ref colour 1) 255.0) (/ (vector-ref colour 2) 255.0)))

    (define (draw-shape c path m st fill?)
      (unless (or (null? path) (equal? (prop st "visibility") "hidden"))
        (let* ((page (ctx-page c))
               (fill (and fill? (paint-for c st "fill" "fill-opacity")))
               (stroke (paint-for c st "stroke" "stroke-opacity"))
               (w (number-or (prop st "stroke-width") 1))
               (stroke (and stroke (> w 0) stroke))
               (stroke-first? (let ((po (prop st "paint-order")))
                                (and po (string-prefix? "stroke" (string-trim-both po))))))
          (define (do-fill)
            (when fill
              (pdf-with-state page
                (lambda ()
                  (apply pdf-transform page (vector->list m))
                  (set-colour! page pdf-set-fill-rgb fill)
                  (when (< (vector-ref fill 3) 1) (pdf-set-opacity page (vector-ref fill 3)))
                  (emit-path! page path)
                  (if (equal? (prop st "fill-rule") "evenodd") (pdf-fill-even-odd page) (pdf-fill page))))))
          (define (do-stroke)
            (when stroke
              (pdf-with-state page
                (lambda ()
                  (apply pdf-transform page (vector->list m))
                  (set-colour! page pdf-set-stroke-rgb stroke)
                  (when (< (vector-ref stroke 3) 1) (pdf-set-opacity page 1.0 (vector-ref stroke 3)))
                  (pdf-set-line-width page w)
                  (let ((join (prop st "stroke-linejoin")) (cap (prop st "stroke-linecap")))
                    (pdf-set-line-join page (cond ((equal? join "round") pdf-line-join-round)
                                                  ((equal? join "bevel") pdf-line-join-bevel)
                                                  (else pdf-line-join-miter)))
                    (pdf-set-line-cap page (cond ((equal? cap "round") pdf-line-cap-round)
                                                 ((equal? cap "square") pdf-line-cap-square)
                                                 (else pdf-line-cap-butt))))
                  (pdf-set-miter-limit page (number-or (prop st "stroke-miterlimit") 4))
                  (let ((d (prop st "stroke-dasharray")))
                    (when (and d (not (string=? (string-trim-both d) "none")))
                      (let ((ns (numbers d)))
                        (when (pair? ns)
                          (pdf-set-dash page (if (odd? (length ns)) (append ns ns) ns)
                                        (number-or (prop st "stroke-dashoffset") 0))))))
                  (emit-path! page path)
                  (pdf-stroke page)))))
          (if stroke-first?
              (begin (do-stroke) (do-fill))
              (begin (do-fill) (do-stroke))))))

    ;; One line of text per element, as in (scm svg raster). The glyphs
    ;; are drawn upright in a frame flipped back from SVG's y-down one.
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
                      (else x)))
             (fill (paint-for c st "fill" "fill-opacity"))
             (stroke (paint-for c st "stroke" "stroke-opacity"))
             (sw (number-or (prop st "stroke-width") 1))
             (page (ctx-page c)))
        (unless (or (string-null? text) (equal? (prop st "visibility") "hidden"))
          ;; a stroke around text (a halo, paint-order stroke) is drawn
          ;; as outlines under the glyphs
          (when (and stroke (> sw 0))
            (draw-shape c (font-text-path font size x y text) m
                        (cons '("fill" . "none")
                              (if (assoc "stroke-linejoin" st) st (cons '("stroke-linejoin" . "round") st)))
                        #f))
          (when fill
            (let ((pf (svg-pdf-font (ctx-doc c) font)))
              (pdf-with-state page
                (lambda ()
                  (apply pdf-transform page (vector->list m))
                  (pdf-transform page 1 0 0 -1 x y)
                  (set-colour! page pdf-set-fill-rgb fill)
                  (when (< (vector-ref fill 3) 1) (pdf-set-opacity page (vector-ref fill 3)))
                  (pdf-draw-text page pf size 0 0 text 'kerning (lambda (a b) (* 1000 (/ (font-kerning font a b) (font-units-per-em font))))))))))))

    (define (root-of svg) (if (string? svg) (svg-text->sxml svg) svg))

    (define (svg-size svg)
      "Syntax: (svg-size svg)
Library: (scm svg pdf)
Description: The width and height of svg (SVG text or SXML) in its own
  units, as two values: the root's width and height, or its viewBox's
  size, or 300 by 150.
Example:
  (svg-size \"<svg width='20' height='10'/>\") => 20 10"
      (let* ((root (root-of svg))
             (vb (let ((v (attr root 'viewBox))) (and v (numbers v)))))
        (values (length-attr root 'width (if (and vb (= (length vb) 4)) (caddr vb) 300))
                (length-attr root 'height (if (and vb (= (length vb) 4)) (cadddr vb) 150)))))

    (define (svg->pdf-page! doc page svg x y . options)
      "Syntax: (svg->pdf-page! doc page svg x y [options])
Library: (scm svg pdf)
Description: Draws svg (SVG text or an SXML tree) on page, a page of doc,
  with its top-left corner at (x, y) in PDF points (y counts from the
  bottom of the page, as everywhere in (scm pdf)). One SVG unit is one
  point unless options give (width . w) or (height . h) in points, which
  scale the drawing (keeping its aspect ratio). Returns the drawn width
  and height as two values. options is an alist: width, height, and
  (fonts . ((normal . font) (bold . font))) fonts of (scm truetype),
  DejaVu Sans by default.
Example:
  (svg->pdf-page! doc page chart 50 790 '((width . 495)))"
      (let* ((options (if (pair? options) (car options) '()))
             (root (root-of svg)))
        (let-values (((w h) (svg-size root)))
          (let* ((s (cond ((option options 'width #f) => (lambda (tw) (/ tw w)))
                          ((option options 'height #f) => (lambda (th) (/ th h)))
                          (else 1.0)))
                 (rules (list '()))
                 (ids (make-hash-table equal?)))
            (collect root rules ids '())
            (let* ((c (make-ctx doc page (car rules) ids
                                (option options 'fonts
                                        (list (cons 'normal dejavu-sans) (cons 'bold dejavu-sans-bold)))
                                1.0))
                   (st (compute-style root '() (car rules) '()))
                   ;; SVG user space (y down) -> PDF (y up), through the viewBox
                   (m (transform-multiply (vector s 0.0 0.0 (- s) x y) (viewbox-transform root w h)))
                   (c (with-opacity c (number-or (prop st "opacity") 1.0)))
                   (anc (list (element-info root))))
              (unless (equal? (prop st "display") "none")
                (for-each (lambda (k) (render-node c k m st anc)) (el-children root)))
              (values (* s w) (* s h)))))))

    (define (svg->pdf svg . options)
      "Syntax: (svg->pdf svg [options])
Library: (scm svg pdf)
Description: A one-page PDF (bytevector) of svg, the page the size of
  the drawing (one SVG unit = one point, or scaled to (width . w) or
  (height . h)) plus (margin . m) points on each side, 0 by default.
  options as for svg->pdf-page!, and (title . s) for the document's
  metadata.
Example:
  (pdf-save-bytes (svg->pdf chart '((width . 400) (margin . 10))))"
      (let* ((options (if (pair? options) (car options) '()))
             (root (root-of svg))
             (margin (option options 'margin 0)))
        (let-values (((w h) (svg-size root)))
          (let* ((s (cond ((option options 'width #f) => (lambda (tw) (/ tw w)))
                          ((option options 'height #f) => (lambda (th) (/ th h)))
                          (else 1.0)))
                 (pw (+ (* s w) (* 2 margin)))
                 (ph (+ (* s h) (* 2 margin)))
                 (doc (make-pdf))
                 (page (pdf-add-page! doc pw ph)))
            (when (option options 'title #f)
              (pdf-set-metadata! doc 'title (option options 'title #f)))
            (svg->pdf-page! doc page root margin (- ph margin)
                            (cons (cons 'width (* s w)) options))
            (pdf->bytevector doc)))))

))
