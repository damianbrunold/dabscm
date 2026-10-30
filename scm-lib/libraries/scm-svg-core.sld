;; (scm svg core) — the format-neutral half of the SVG renderers: an XML
;; reader to SXML, the tree accessors, numbers, transforms, path data
;; (arcs become cubics), CSS rules and the cascade, paints, and the
;; geometry of the basic shapes. (scm svg raster) draws with it on a
;; canvas, (scm svg pdf) on a PDF page; both support the same subset of
;; SVG, described in (scm svg raster).
;;
;; Paths are lists of absolute commands (M x y) (L x y) (Q x1 y1 x y)
;; (C x1 y1 x2 y2 x y) (Z), the form (scm raster) takes; transforms are
;; vectors #(a b c d e f) as in (scm raster).

(define-library (scm svg core)
  (export svg-text->sxml
          el-attrs
          el-children
          element?
          attr
          node-text
          numbers
          number-or
          parse-transform
          invert
          scale-factor
          parse-path-data
          parse-css
          parse-declarations
          compute-style
          prop
          element-info
          parse-paint
          with-alpha
          collect
          length-attr
          viewbox-transform
          shape-path
          collapse-spaces
          option)
  (import (scheme base)
          (scheme char)
          (scheme inexact)
          (scheme cxr)
          (srfi 1)
          (srfi 13)
          (only (srfi 69) hash-table-set!)
          (scm html builder)
          (scm raster))
  (begin

    ;; --- XML text -> SXML -----------------------------------------------

    ;; A small XML reader for SVG documents: elements, attributes,
    ;; text, entities, comments, CDATA; the prolog, doctype and
    ;; processing instructions are skipped. Namespace prefixes are kept
    ;; as part of the name (xlink:href).
    (define (svg-text->sxml text)
      "Syntax: (svg-text->sxml text)
Library: (scm svg core)
Description: Parses SVG (or other simple XML) text into SXML, the tree
  shape svg->canvas accepts: (tag (@ (name \"value\") ...) child ...).
  Comments, the prolog, the doctype and processing instructions are
  dropped; entities are decoded.
Example:
  (svg-text->sxml \"<svg width='10'><rect/></svg>\")
  => (svg (@ (width \"10\")) (rect (@)))"
      (let ((n (string-length text)))
        (define (at? i s) (and (<= (+ i (string-length s)) n)
                               (string=? (substring text i (+ i (string-length s))) s)))
        (define (skip-to i s)
          (let ((j (string-contains text s i)))
            (if j (+ j (string-length s)) n)))
        (define (name-char? c) (or (char-alphabetic? c) (char-numeric? c)
                                   (memv c '(#\- #\_ #\: #\.))))
        (define (read-name i)
          (let loop ((j i))
            (if (and (< j n) (name-char? (string-ref text j)))
                (loop (+ j 1))
                (values (substring text i j) j))))
        (define (skip-ws i)
          (if (and (< i n) (char-whitespace? (string-ref text i))) (skip-ws (+ i 1)) i))
        ;; -> (values attrs i), i after > or />, and whether it closed
        (define (read-attrs i)
          (let loop ((i (skip-ws i)) (acc '()))
            (cond
             ((>= i n) (values (reverse acc) n #t))
             ((at? i "/>") (values (reverse acc) (+ i 2) #t))
             ((char=? (string-ref text i) #\>) (values (reverse acc) (+ i 1) #f))
             (else
              (let-values (((name j) (read-name i)))
                (if (string-null? name)
                    (loop (skip-ws (+ i 1)) acc)
                    (let ((j (skip-ws j)))
                      (if (and (< j n) (char=? (string-ref text j) #\=))
                          (let* ((k (skip-ws (+ j 1)))
                                 (q (string-ref text k))
                                 (e (or (string-index text q (+ k 1)) n)))
                            (loop (skip-ws (+ e 1))
                                  (cons (list (string->symbol name)
                                              (decode-entities (substring text (+ k 1) e)))
                                        acc)))
                          (loop j (cons (list (string->symbol name) "") acc))))))))))
        ;; -> (values children i) up to the closing tag of the parent
        (define (read-content i)
          (let loop ((i i) (acc '()))
            (cond
             ((>= i n) (values (reverse acc) n))
             ((at? i "</") (values (reverse acc) (skip-to i ">")))
             ((at? i "<!--") (loop (skip-to i "-->") acc))
             ((at? i "<![CDATA[")
              (let ((e (or (string-contains text "]]>" i) n)))
                (loop (min n (+ e 3)) (cons (substring text (+ i 9) e) acc))))
             ((or (at? i "<?") (at? i "<!")) (loop (skip-to i ">") acc))
             ((char=? (string-ref text i) #\<)
              (let-values (((name j) (read-name (+ i 1))))
                (let-values (((attrs k closed?) (read-attrs j)))
                  (if closed?
                      (loop k (cons (cons* (string->symbol name) (cons '@ attrs) '()) acc))
                      (let-values (((children k) (read-content k)))
                        (loop k (cons (cons* (string->symbol name) (cons '@ attrs) children)
                                      acc)))))))
             (else
              (let ((e (or (string-index text #\< i) n)))
                (loop e (cons (decode-entities (substring text i e)) acc)))))))
        (let-values (((nodes i) (read-content 0)))
          (or (find pair? nodes)
              (error "svg-text->sxml: no element found")))))

    (define (decode-entities s)
      (if (not (string-index s #\&))
          s
          (let ((n (string-length s)))
            (let loop ((i 0) (acc '()))
              (if (>= i n)
                  (list->string (reverse acc))
                  (let ((c (string-ref s i)))
                    (if (char=? c #\&)
                        (let* ((e (string-index s #\; i))
                               (name (and e (substring s (+ i 1) e)))
                               (ch (and name (entity name))))
                          (if ch
                              (loop (+ e 1) (cons ch acc))
                              (loop (+ i 1) (cons c acc))))
                        (loop (+ i 1) (cons c acc)))))))))

    (define (entity name)
      (cond
       ((string=? name "amp") #\&) ((string=? name "lt") #\<) ((string=? name "gt") #\>)
       ((string=? name "quot") #\") ((string=? name "apos") #\')
       ((string=? name "nbsp") (integer->char #xA0))
       ((string-prefix? "#x" name)
        (let ((v (string->number (substring name 2 (string-length name)) 16)))
          (and v (integer->char v))))
       ((string-prefix? "#" name)
        (let ((v (string->number (substring name 1 (string-length name)))))
          (and v (integer->char v))))
       (else #f)))

    ;; --- the tree -------------------------------------------------------

    ;; attributes as an alist of symbol -> string; children with
    ;; fragments spliced and #f / () dropped, as (scm html builder) does
    (define (el-attrs node)
      (if (and (pair? (cdr node)) (pair? (cadr node)) (eq? (car (cadr node)) '@))
          (filter-map (lambda (a)
                        (let ((v (if (pair? (cdr a)) (cadr a) #f)))
                          (cond ((string? v) (cons (car a) v))
                                ((number? v) (cons (car a) (number->string v)))
                                ((raw? v) (cons (car a) (raw-value v)))
                                ((eq? v #t) (cons (car a) ""))
                                (else #f))))
                      (cdr (cadr node)))
          '()))

    (define (el-children node)
      (let ((body (if (and (pair? (cdr node)) (pair? (cadr node)) (eq? (car (cadr node)) '@))
                      (cddr node)
                      (cdr node))))
        (let flat ((xs body) (acc '()))
          (cond
           ((null? xs) (reverse acc))
           (else
            (let ((x (car xs)))
              (cond
               ((or (not x) (null? x)) (flat (cdr xs) acc))
               ((and (pair? x) (not (symbol? (car x))))
                (flat (cdr xs) (append (reverse (el-children (cons 'fragment x))) acc)))
               (else (flat (cdr xs) (cons x acc))))))))))

    (define (element? x) (and (pair? x) (symbol? (car x))))

    (define (attr node name . default)
      (let ((p (assq name (el-attrs node))))
        (if p (cdr p) (if (pair? default) (car default) #f))))

    ;; text content of a node: strings, numbers and raw text, recursively
    (define (node-text node)
      (apply string-append
             (map (lambda (c)
                    (cond ((string? c) c)
                          ((number? c) (number->string c))
                          ((raw? c) (raw-value c))
                          ((element? c) (node-text c))
                          (else "")))
                  (el-children node))))

    ;; --- numbers --------------------------------------------------------

    ;; The numbers in s, in order: "1,2 -3.5e2.5" -> (1 2 -350 0.5)
    (define (numbers s)
      (let ((n (string-length s)))
        (let loop ((i 0) (acc '()))
          (let ((i (skip-separators s i)))
            (if (>= i n)
                (reverse acc)
                (let-values (((v j) (read-number s i)))
                  (if v (loop j (cons v acc)) (loop (+ i 1) acc))))))))

    (define (skip-separators s i)
      (if (and (< i (string-length s))
               (let ((c (string-ref s i))) (or (char-whitespace? c) (char=? c #\,))))
          (skip-separators s (+ i 1))
          i))

    ;; A number at i: sign, digits, fraction, exponent. -> (values v j),
    ;; v #f when there is none. Digits are accumulated by hand: this runs
    ;; for every coordinate of every path.
    (define (read-number s i)
      (let* ((n (string-length s))
             (neg? (and (< i n) (char=? (string-ref s i) #\-)))
             (i0 (if (and (< i n) (memv (string-ref s i) '(#\- #\+))) (+ i 1) i)))
        (define (digit j) (- (char->integer (string-ref s j)) 48))
        (define (digit? j) (and (< j n) (char-numeric? (string-ref s j))))
        (let int ((j i0) (v 0) (any? #f))
          (if (digit? j)
              (int (+ j 1) (+ (* v 10) (digit j)) #t)
              (let-values (((v j any?)
                            (if (and (< j n) (char=? (string-ref s j) #\.) (digit? (+ j 1)))
                                (let frac ((j (+ j 1)) (v (inexact v)) (scale 0.1))
                                  (if (digit? j)
                                      (frac (+ j 1) (+ v (* scale (digit j))) (* scale 0.1))
                                      (values v j #t)))
                                (values v j any?))))
                (if (not any?)
                    (values #f i)
                    (let-values (((v j)
                                  (if (and (< j n) (memv (string-ref s j) '(#\e #\E))
                                           (let ((k (if (and (< (+ j 1) n)
                                                             (memv (string-ref s (+ j 1)) '(#\- #\+)))
                                                        (+ j 2) (+ j 1))))
                                             (digit? k)))
                                      (let* ((eneg? (char=? (string-ref s (+ j 1)) #\-))
                                             (k (if (memv (string-ref s (+ j 1)) '(#\- #\+)) (+ j 2) (+ j 1))))
                                        (let ex ((k k) (e 0))
                                          (if (digit? k)
                                              (ex (+ k 1) (+ (* e 10) (digit k)))
                                              (values (* v (expt 10.0 (if eneg? (- e) e))) k))))
                                      (values v j))))
                      (values (inexact (if neg? (- v) v)) j))))))))

    (define (number-or s default)
      (if (not s)
          default
          (let-values (((v j) (read-number (string-trim-both s) 0)))
            (or v default))))

    ;; --- transforms -------------------------------------------------------

    (define (parse-transform s)
      (let ((n (string-length s)))
        (let loop ((i 0) (m (transform-identity)))
          (let ((open (string-index s #\( i)))
            (if (not open)
                m
                (let* ((name (string-trim-both (substring s i open)
                                               (lambda (c) (or (char-whitespace? c)
                                                               (char=? c #\,)))))
                       (close (or (string-index s #\) open) n))
                       (args (numbers (substring s (+ open 1) close)))
                       (arg (lambda (k d) (if (> (length args) k) (list-ref args k) d)))
                       (t (cond
                           ((string=? name "matrix")
                            (if (= (length args) 6) (list->vector args) (transform-identity)))
                           ((string=? name "translate") (transform-translate (arg 0 0) (arg 1 0)))
                           ((string=? name "scale") (transform-scale (arg 0 1) (arg 1 (arg 0 1))))
                           ((string=? name "rotate")
                            (if (= (length args) 3)
                                (transform-multiply
                                 (transform-translate (arg 1 0) (arg 2 0))
                                 (transform-multiply (transform-rotate (arg 0 0))
                                                     (transform-translate (- (arg 1 0)) (- (arg 2 0)))))
                                (transform-rotate (arg 0 0))))
                           ((string=? name "skewX")
                            (vector 1.0 0.0 (tan (* (arg 0 0) (/ pi 180))) 1.0 0.0 0.0))
                           ((string=? name "skewY")
                            (vector 1.0 (tan (* (arg 0 0) (/ pi 180))) 0.0 1.0 0.0 0.0))
                           (else (transform-identity)))))
                  (loop (+ close 1) (transform-multiply m t))))))))

    (define pi (* 4 (atan 1)))

    (define (invert m)
      (let* ((a (vector-ref m 0)) (b (vector-ref m 1)) (c (vector-ref m 2))
             (d (vector-ref m 3)) (e (vector-ref m 4)) (f (vector-ref m 5))
             (det (- (* a d) (* b c))))
        (if (< (abs det) 1e-12)
            (transform-identity)
            (vector (/ d det) (/ (- b) det) (/ (- c) det) (/ a det)
                    (/ (- (* c f) (* d e)) det) (/ (- (* b e) (* a f)) det)))))

    (define (scale-factor m)
      (sqrt (abs (- (* (vector-ref m 0) (vector-ref m 3))
                    (* (vector-ref m 1) (vector-ref m 2))))))

    ;; --- path data --------------------------------------------------------

    ;; SVG path data -> absolute (M L Q C Z) commands for (scm raster)
    (define (parse-path-data d)
      (let ((n (string-length d)))
        (define (num i)
          (let-values (((v j) (read-number d (skip-separators d i))))
            (values v j)))
        ;; arc flags may be written without separators: "a5 5 0 01 10 0"
        (define (flag i)
          (let ((i (skip-separators d i)))
            (if (and (< i n) (memv (string-ref d i) '(#\0 #\1)))
                (values (char=? (string-ref d i) #\1) (+ i 1))
                (values #f i))))
        (let loop ((i 0) (cmd #f) (x 0.0) (y 0.0) (sx 0.0) (sy 0.0)
                   (cx #f) (cy #f) (qx #f) (qy #f) (acc '()))
          (let ((i (skip-separators d i)))
            (cond
             ((>= i n) (reverse acc))
             ((char-alphabetic? (string-ref d i))
              (let ((c (string-ref d i)))
                (if (memv c '(#\z #\Z))
                    (loop (+ i 1) c sx sy sx sy #f #f #f #f (cons '(Z) acc))
                    (loop (+ i 1) c x y sx sy cx cy qx qy acc))))
             ((not cmd) (reverse acc))
             (else
              (let* ((rel? (char-lower-case? cmd))
                     (ox (if rel? x 0.0)) (oy (if rel? y 0.0))
                     (k (char-upcase cmd)))
                (case k
                  ((#\M #\L)
                   (let*-values (((a i) (num i)) ((b i) (num i)))
                     (if (not (and a b))
                         (reverse acc)
                         (let ((nx (+ ox a)) (ny (+ oy b)))
                           (if (char=? k #\M)
                               ;; further pairs after a moveto are linetos
                               (loop i (if rel? #\l #\L) nx ny nx ny #f #f #f #f
                                     (cons (list 'M nx ny) acc))
                               (loop i cmd nx ny sx sy #f #f #f #f (cons (list 'L nx ny) acc)))))))
                  ((#\H)
                   (let-values (((a i) (num i)))
                     (if (not a) (reverse acc)
                         (let ((nx (+ ox a)))
                           (loop i cmd nx y sx sy #f #f #f #f (cons (list 'L nx y) acc))))))
                  ((#\V)
                   (let-values (((a i) (num i)))
                     (if (not a) (reverse acc)
                         (let ((ny (+ oy a)))
                           (loop i cmd x ny sx sy #f #f #f #f (cons (list 'L x ny) acc))))))
                  ((#\C #\S)
                   (let*-values (((vals i) (read-n num i (if (char=? k #\C) 6 4))))
                     (if (not vals) (reverse acc)
                         (let*-values (((x1 y1 rest)
                                        (if (char=? k #\C)
                                            (values (+ ox (car vals)) (+ oy (cadr vals)) (cddr vals))
                                            ;; reflect the last control point
                                            (values (if cx (- (* 2 x) cx) x) (if cy (- (* 2 y) cy) y) vals)))
                                       ((x2) (+ ox (car rest)))
                                       ((y2) (+ oy (cadr rest)))
                                       ((ex) (+ ox (caddr rest)))
                                       ((ey) (+ oy (cadddr rest))))
                           (loop i cmd ex ey sx sy x2 y2 #f #f
                                 (cons (list 'C x1 y1 x2 y2 ex ey) acc))))))
                  ((#\Q #\T)
                   (let*-values (((vals i) (read-n num i (if (char=? k #\Q) 4 2))))
                     (if (not vals) (reverse acc)
                         (let*-values (((x1 y1 rest)
                                        (if (char=? k #\Q)
                                            (values (+ ox (car vals)) (+ oy (cadr vals)) (cddr vals))
                                            (values (if qx (- (* 2 x) qx) x) (if qy (- (* 2 y) qy) y) vals)))
                                       ((ex) (+ ox (car rest)))
                                       ((ey) (+ oy (cadr rest))))
                           (loop i cmd ex ey sx sy #f #f x1 y1
                                 (cons (list 'Q x1 y1 ex ey) acc))))))
                  ((#\A)
                   (let*-values (((rx i) (num i)) ((ry i) (num i)) ((rot i) (num i))
                                 ((large i) (flag i)) ((sweep i) (flag i))
                                 ((a i) (num i)) ((b i) (num i)))
                     (if (not (and rx ry rot a b)) (reverse acc)
                         (let ((ex (+ ox a)) (ey (+ oy b)))
                           (loop i cmd ex ey sx sy #f #f #f #f
                                 (append (reverse (arc->cubics x y rx ry rot large sweep ex ey))
                                         acc))))))
                  (else (reverse acc))))))))))

    (define (read-n num i k)
      (let loop ((i i) (k k) (acc '()))
        (if (= k 0)
            (values (reverse acc) i)
            (let-values (((v j) (num i)))
              (if v (loop j (- k 1) (cons v acc)) (values #f i))))))

    ;; Elliptical arc (SVG endpoint form) -> cubic Beziers, at most a
    ;; quarter turn each (SVG 1.1, appendix F.6).
    (define (arc->cubics x1 y1 rx ry rot large? sweep? x2 y2)
      (if (or (= rx 0) (= ry 0) (and (= x1 x2) (= y1 y2)))
          (list (list 'L x2 y2))
          (let* ((rx (abs rx)) (ry (abs ry))
                 (phi (* rot (/ pi 180))) (cp (cos phi)) (sp (sin phi))
                 (dx (/ (- x1 x2) 2)) (dy (/ (- y1 y2) 2))
                 (x1p (+ (* cp dx) (* sp dy))) (y1p (+ (* (- sp) dx) (* cp dy)))
                 (lam (+ (/ (* x1p x1p) (* rx rx)) (/ (* y1p y1p) (* ry ry))))
                 (rx (if (> lam 1) (* rx (sqrt lam)) rx))
                 (ry (if (> lam 1) (* ry (sqrt lam)) ry))
                 (num (- (* rx rx ry ry) (* rx rx y1p y1p) (* ry ry x1p x1p)))
                 (den (+ (* rx rx y1p y1p) (* ry ry x1p x1p)))
                 (co (* (if (eq? large? sweep?) -1 1) (sqrt (max 0 (/ num den)))))
                 (cxp (* co (/ (* rx y1p) ry))) (cyp (* co (- (/ (* ry x1p) rx))))
                 (cx (+ (- (* cp cxp) (* sp cyp)) (/ (+ x1 x2) 2)))
                 (cy (+ (+ (* sp cxp) (* cp cyp)) (/ (+ y1 y2) 2)))
                 (angle (lambda (ux uy vx vy)
                          (let ((a (atan (- (* ux vy) (* uy vx)) (+ (* ux vx) (* uy vy))))) a)))
                 (t1 (angle 1 0 (/ (- x1p cxp) rx) (/ (- y1p cyp) ry)))
                 (dt (angle (/ (- x1p cxp) rx) (/ (- y1p cyp) ry)
                            (/ (- (- x1p) cxp) rx) (/ (- (- y1p) cyp) ry)))
                 (dt (cond ((and (not sweep?) (> dt 0)) (- dt (* 2 pi)))
                           ((and sweep? (< dt 0)) (+ dt (* 2 pi)))
                           (else dt)))
                 (segs (max 1 (exact (ceiling (/ (abs dt) (/ pi 2))))))
                 (step (/ dt segs))
                 (k (* 4/3 (tan (/ step 4))))
                 (pt (lambda (t) (let ((ct (cos t)) (st (sin t)))
                                   (values (+ cx (* rx cp ct) (- (* ry sp st)))
                                           (+ cy (* rx sp ct) (* ry cp st))))))
                 (dpt (lambda (t) (let ((ct (cos t)) (st (sin t)))
                                    (values (- (* -1 rx cp st) (* ry sp ct))
                                            (+ (* -1 rx sp st) (* ry cp ct)))))))
            (let loop ((s 0) (acc '()))
              (if (= s segs)
                  (reverse acc)
                  (let ((ta (+ t1 (* s step))) (tb (+ t1 (* (+ s 1) step))))
                    (let-values (((ax ay) (pt ta)) ((bx by) (pt tb))
                                 ((dax day) (dpt ta)) ((dbx dby) (dpt tb)))
                      (loop (+ s 1)
                            (cons (list 'C (+ ax (* k dax)) (+ ay (* k day))
                                        (- bx (* k dbx)) (- by (* k dby))
                                        (if (= s (- segs 1)) x2 bx) (if (= s (- segs 1)) y2 by))
                                  acc)))))))))

    ;; --- CSS --------------------------------------------------------------

    ;; A rule: (specificity order compounds . declarations); a compound is
    ;; (tag id classes), tag and id #f when absent. Declarations are an
    ;; alist property -> value, both strings.
    (define (parse-css text)
      (let ((text (strip-comments text)) (n 0))
        (let loop ((i 0) (order 0) (acc '()))
          (let ((open (string-index text #\{ i)))
            (if (not open)
                (reverse acc)
                (let ((head (string-trim-both (substring text i open))))
                  (if (string-prefix? "@" head)
                      ;; an at-rule block: skipped with what it holds
                      (loop (skip-block text open) order acc)
                      (let* ((close (or (string-index text #\} open) (string-length text)))
                             (decls (parse-declarations (substring text (+ open 1) close)))
                             (rules (filter-map
                                     (lambda (sel)
                                       (let ((cs (parse-selector sel)))
                                         (and cs (cons* (specificity cs) order cs decls))))
                                     (string-split-char head #\,))))
                        (loop (+ close 1) (+ order 1) (append (reverse rules) acc))))))))))

    (define (strip-comments s)
      (let ((i (string-contains s "/*")))
        (if (not i)
            s
            (let ((e (string-contains s "*/" (+ i 2))))
              (string-append (substring s 0 i)
                             (strip-comments (if e (substring s (+ e 2) (string-length s)) "")))))))

    ;; index after the } that closes the { at open
    (define (skip-block s open)
      (let loop ((i (+ open 1)) (depth 1))
        (cond ((>= i (string-length s)) i)
              ((char=? (string-ref s i) #\{) (loop (+ i 1) (+ depth 1)))
              ((char=? (string-ref s i) #\}) (if (= depth 1) (+ i 1) (loop (+ i 1) (- depth 1))))
              (else (loop (+ i 1) depth)))))

    (define (string-split-char s c)
      (let loop ((i 0) (acc '()))
        (let ((j (string-index s c i)))
          (if j
              (loop (+ j 1) (cons (substring s i j) acc))
              (reverse (cons (substring s i (string-length s)) acc))))))

    (define (parse-declarations s)
      (filter-map (lambda (d)
                    (let ((colon (string-index d #\:)))
                      (and colon
                           (let ((v (string-trim-both (substring d (+ colon 1) (string-length d)))))
                             (cons (string-downcase (string-trim-both (substring d 0 colon)))
                                   (let ((imp (string-contains v "!important")))
                                     (if imp (string-trim-both (substring v 0 imp)) v)))))))
                  (string-split-char s #\;)))

    ;; "g .a.b #c" -> compounds, or #f for what is not supported
    (define (parse-selector sel)
      (let ((parts (string-tokenize sel)))
        (and (pair? parts)
             (every (lambda (p) (not (string-any (lambda (c) (memv c '(#\: #\[ #\> #\+ #\~))) p)))
                    parts)
             (map parse-compound parts))))

    (define (parse-compound p)
      (let loop ((i 0) (tag #f) (id #f) (classes '()))
        (if (>= i (string-length p))
            (list tag id classes)
            (let* ((c (string-ref p i))
                   (e (let find ((j (+ i 1)))
                        (if (and (< j (string-length p))
                                 (not (memv (string-ref p j) '(#\. #\#))))
                            (find (+ j 1))
                            j)))
                   (name (substring p (if (memv c '(#\. #\#)) (+ i 1) i) e)))
              (case c
                ((#\.) (loop e tag id (cons name classes)))
                ((#\#) (loop e tag name classes))
                (else (loop e (if (string=? name "*") #f name) id classes)))))))

    ;; ids, classes, types: compared as one number
    (define (specificity compounds)
      (fold (lambda (c s)
              (+ s (if (cadr c) 10000 0) (* 100 (length (caddr c))) (if (car c) 1 0)))
            0 compounds))

    ;; info: (tag id classes) of an element
    (define (compound-matches? c info)
      (and (or (not (car c)) (string=? (car c) (car info)))
           (or (not (cadr c)) (equal? (cadr c) (cadr info)))
           (every (lambda (k) (member k (caddr info))) (caddr c))))

    ;; compounds right to left: the last matches the element, the others
    ;; ancestors in order (descendant combinator)
    (define (selector-matches? compounds info ancestors)
      (let ((rev (reverse compounds)))
        (and (compound-matches? (car rev) info)
             (let loop ((cs (cdr rev)) (as ancestors))
               (cond ((null? cs) #t)
                     ((null? as) #f)
                     ((compound-matches? (car cs) (car as)) (loop (cdr cs) (cdr as)))
                     (else (loop cs (cdr as))))))))

    (define (element-info node)
      (list (symbol->string (car node))
            (attr node 'id)
            (let ((c (attr node 'class))) (if c (string-tokenize c) '()))))

    ;; --- style --------------------------------------------------------------

    (define inherited
      '("fill" "fill-opacity" "fill-rule" "stroke" "stroke-width" "stroke-opacity"
        "stroke-linejoin" "stroke-linecap" "stroke-miterlimit" "stroke-dasharray"
        "stroke-dashoffset" "font-size" "font-weight" "font-family" "text-anchor"
        "paint-order" "visibility"))

    (define presentation
      (append inherited '("opacity" "display")))

    (define initial-style
      '(("fill" . "black") ("stroke" . "none") ("stroke-width" . "1")
        ("font-size" . "16") ("font-weight" . "normal") ("text-anchor" . "start")))

    ;; parent: the parent's computed style (an alist); returns this
    ;; element's, inherited properties first overridden by presentation
    ;; attributes, then matching rules by specificity and order, then the
    ;; style attribute
    (define (compute-style node parent rules ancestors)
      (let* ((info (element-info node))
             (base (filter (lambda (p) (member (car p) inherited)) parent))
             (attrs (filter-map (lambda (a)
                                  (let ((name (symbol->string (car a))))
                                    (and (member name presentation) (cons name (cdr a)))))
                                (el-attrs node)))
             (matched (filter (lambda (r) (selector-matches? (caddr r) info ancestors)) rules))
             (sorted (sort-rules matched))
             (inline (let ((s (attr node 'style))) (if s (parse-declarations s) '()))))
        (fold (lambda (decls style)
                (fold (lambda (d style) (cons d (alist-delete (car d) style)))
                      style decls))
              base
              (append (list attrs) (map cdddr sorted) (list inline)))))

    (define (sort-rules rules)
      ;; insertion sort: a few rules match any one element
      (fold (lambda (r sorted)
              (let loop ((s sorted))
                (cond ((null? s) (list r))
                      ((or (< (car r) (caar s))
                           (and (= (car r) (caar s)) (< (cadr r) (cadr (car s)))))
                       (cons r s))
                      (else (cons (car s) (loop (cdr s)))))))
            '() rules))

    (define (prop style name)
      (let ((p (assoc name style)))
        (if p (cdr p) (let ((i (assoc name initial-style))) (and i (cdr i))))))

    ;; --- paint ------------------------------------------------------------

    (define named-colors
      '(("black" 0 0 0) ("white" 255 255 255) ("red" 255 0 0) ("green" 0 128 0)
        ("blue" 0 0 255) ("yellow" 255 255 0) ("gray" 128 128 128) ("grey" 128 128 128)
        ("silver" 192 192 192) ("maroon" 128 0 0) ("purple" 128 0 128) ("fuchsia" 255 0 255)
        ("lime" 0 255 0) ("olive" 128 128 0) ("navy" 0 0 128) ("teal" 0 128 128)
        ("aqua" 0 255 255) ("orange" 255 165 0) ("lightgray" 211 211 211)
        ("lightgrey" 211 211 211) ("darkgray" 169 169 169) ("darkgrey" 169 169 169)))

    (define (hex2 s i) (string->number (substring s i (+ i 2)) 16))
    (define (hex1 s i) (let ((v (string->number (substring s i (+ i 1)) 16))) (and v (* 17 v))))

    ;; -> rgba vector, 'none, (url . id), or #f when not understood
    (define (parse-paint s)
      (let ((s (string-trim-both (string-downcase s))))
        (cond
         ((or (string=? s "none") (string=? s "transparent")) 'none)
         ((string-prefix? "url(" s)
          (let* ((close (or (string-index s #\)) (string-length s)))
                 (inner (string-trim-both (substring s 4 close)))
                 (inner (string-trim-both inner (lambda (c) (memv c '(#\" #\'))))))
            (cons 'url (if (string-prefix? "#" inner) (substring inner 1 (string-length inner)) inner))))
         ((string-prefix? "#" s)
          (case (string-length s)
            ((4) (let ((r (hex1 s 1)) (g (hex1 s 2)) (b (hex1 s 3))) (and r g b (rgba r g b))))
            ((7) (let ((r (hex2 s 1)) (g (hex2 s 3)) (b (hex2 s 5))) (and r g b (rgba r g b))))
            ((9) (let ((r (hex2 s 1)) (g (hex2 s 3)) (b (hex2 s 5)) (a (hex2 s 7)))
                   (and r g b a (rgba r g b (/ a 255.0)))))
            (else #f)))
         ((or (string-prefix? "rgb(" s) (string-prefix? "rgba(" s))
          (let* ((open (string-index s #\())
                 (close (or (string-index s #\)) (string-length s)))
                 (parts (map string-trim-both
                             (string-split-char
                              (string-map (lambda (c) (if (char=? c #\/) #\, c))
                                          (substring s (+ open 1) close))
                              #\,)))
                 (parts (if (= (length parts) 1) (string-tokenize (car parts)) parts))
                 (chan (lambda (p) (if (string-suffix? "%" p)
                                       (* 2.55 (number-or (substring p 0 (- (string-length p) 1)) 0))
                                       (number-or p 0))))
                 (clamp (lambda (v) (max 0 (min 255 (exact (round v)))))))
            (and (>= (length parts) 3)
                 (rgba (clamp (chan (car parts))) (clamp (chan (cadr parts))) (clamp (chan (caddr parts)))
                       (if (> (length parts) 3)
                           (let ((a (cadddr parts)))
                             (if (string-suffix? "%" a)
                                 (/ (number-or (substring a 0 (- (string-length a) 1)) 100) 100.0)
                                 (number-or a 1.0)))
                           1.0)))))
         ((assoc s named-colors) => (lambda (c) (apply rgba (cdr c))))
         (else #f))))

    (define (with-alpha c a)
      (vector (vector-ref c 0) (vector-ref c 1) (vector-ref c 2) (* a (vector-ref c 3))))

    ;; Style sheets and ids of the whole document, found first so that a
    ;; reference may precede its target. ids maps an id to (node .
    ;; ancestors): a pattern's content is styled where the pattern
    ;; stands, so a descendant selector such as ".chart .hatch" reaches
    ;; into it.
    (define (collect node rules ids ancestors)
      (when (element? node)
        (let ((id (attr node 'id)))
          (when id (hash-table-set! ids id (cons node ancestors))))
        (if (eq? (car node) 'style)
            (set-car! rules (append (car rules) (parse-css (node-text node))))
            (let ((anc (cons (element-info node) ancestors)))
              (for-each (lambda (c) (collect c rules ids anc)) (el-children node))))))

    (define (length-attr node name default)
      (let ((v (attr node name)))
        (if (and v (not (string-suffix? "%" v))) (number-or v default) default)))

    ;; from the viewBox to the element's own width and height; width and
    ;; height default to the viewBox's (preserveAspectRatio xMidYMid meet)
    (define (viewbox-transform node width height)
      (let ((vb (let ((v (attr node 'viewBox))) (and v (numbers v)))))
        (if (not (and vb (= (length vb) 4) (> (caddr vb) 0) (> (cadddr vb) 0)))
            (transform-identity)
            (let* ((w (or width (length-attr node 'width (caddr vb))))
                   (h (or height (length-attr node 'height (cadddr vb))))
                   (s (min (/ w (caddr vb)) (/ h (cadddr vb))))
                   (tx (- (/ (- w (* s (caddr vb))) 2) (* s (car vb))))
                   (ty (- (/ (- h (* s (cadddr vb))) 2) (* s (cadr vb)))))
              (vector s 0.0 0.0 s tx ty)))))

    (define (shape-path node)
      (let ((n (lambda (name) (length-attr node name 0))))
        (case (car node)
          ((rect)
           (let* ((w (n 'width)) (h (n 'height))
                  (rx (attr node 'rx)) (ry (attr node 'ry))
                  (rx (number-or (or rx ry) 0)) (ry (number-or (or ry (attr node 'rx)) 0)))
             (if (and (> w 0) (> h 0)) (path-rect (n 'x) (n 'y) w h rx ry) '())))
          ((circle) (if (> (n 'r) 0) (path-circle (n 'cx) (n 'cy) (n 'r)) '()))
          ((ellipse) (if (and (> (n 'rx) 0) (> (n 'ry) 0))
                         (path-ellipse (n 'cx) (n 'cy) (n 'rx) (n 'ry)) '()))
          ((line) `((M ,(n 'x1) ,(n 'y1)) (L ,(n 'x2) ,(n 'y2))))
          ((polyline polygon)
           (let loop ((ns (numbers (or (attr node 'points) ""))) (acc '()))
             (if (or (null? ns) (null? (cdr ns)))
                 (path-polyline (reverse acc) (eq? (car node) 'polygon))
                 (loop (cddr ns) (cons (cons (car ns) (cadr ns)) acc)))))
          ((path) (parse-path-data (or (attr node 'd) "")))
          (else '()))))

    (define (collapse-spaces s)
      (let loop ((cs (string->list s)) (acc '()) (space? #f))
        (cond ((null? cs) (string-trim-both (list->string (reverse acc))))
              ((char-whitespace? (car cs)) (loop (cdr cs) acc #t))
              (else (loop (cdr cs) (cons (car cs) (if (and space? (pair? acc)) (cons #\space acc) acc)) #f)))))

    (define (option options key default)
      (let ((p (assq key options))) (if p (cdr p) default)))


))
