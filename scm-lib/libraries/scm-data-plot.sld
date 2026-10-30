(define-library (scm data plot)
  (import (scheme base)
          (scheme char)
          (scheme cxr)
          (scheme file)
          (scheme inexact)
          (srfi 1)
          (except (srfi 13) string-hash)
          (srfi 69)
          (srfi 132)
          (scm html builder)
          (scm truetype)
          (scm fonts dejavu)
          (scm svg raster)
          (scm svg pdf)
          (scm data core)
          (scm data format)
          (scm data frame)
          (scm data expr)
          (scm data verbs)
          (prefix (scm data stats) stats:))
  (export ggplot
          make-plot
          plot?
          plot-add
          plot->svg
          plot->svg-string
          plot->png
          plot->pdf
          save-plot
          plot-css
          bar-chart
          line-chart
          scatter-plot
          histogram)
  (begin

    ;; ================================================================
    ;; (scm data plot) — charts in the style of ggplot2, rendered to SVG
    ;; (as SXML, see (scm html builder)) and, via (scm svg raster), PNG.
    ;;
    ;;   (ggplot df (aes (x splg) (y points) (fill model))
    ;;     (geom-col (position dodge))
    ;;     (coord-flip)
    ;;     (labs (title "MFZO points") (x #f) (y "Points")))
    ;;
    ;; ggplot quasiquotes its specs: aesthetics are column expressions as
    ;; in (scm data verbs), Scheme values come in with unquote. Specs:
    ;;   (aes (x e) (y e) (fill e) (color e) (label e) (group e))
    ;;   (geom-col [(position stack|dodge|fill)] [(labels #t)] [(aes …)] [(data ,df)])
    ;;   (geom-bar …)        counts rows per x (and fill)
    ;;   (geom-line …) (geom-point …) (geom-area [(position stack)])
    ;;   (geom-histogram [(bins n)|(binwidth w)]) (geom-boxplot)
    ;;   (geom-text) (geom-hline (yintercept v)) (geom-vline (xintercept v))
    ;;   (labs (title s) (subtitle s) (caption s) (x s|#f) (y s|#f) (fill s) (color s))
    ;;   (scale-x …) (scale-y …): (labels fmt) with fmt a procedure or num,
    ;;     int, pct, si; (limits lo hi); (levels a b …) order of a discrete
    ;;     axis; (log10)
    ;;   (coord-flip)  (facet-wrap col [(ncol n)])
    ;;   (theme (width px) (height px) (font-size px) (legend right|bottom|none))
    ;;
    ;; Look: thin bars (at most 24px) with a 4px rounded data end, 2px
    ;; lines, dots with a surface ring, 2px gaps between touching bars,
    ;; hairline gridlines on the value axis only, text in ink colours, a
    ;; legend from two series on, at most eight categorical colours (a
    ;; colour-blind-checked palette, fixed order). Marks carry <title>
    ;; tooltips. Colours are CSS classes (viz-…) set by an embedded style
    ;; sheet; plot-css gives the sheet incl. a dark variant for HTML pages.
    ;; ================================================================

    ;; --- palette -----------------------------------------------------

    (define categorical-light '("#2a78d6" "#eb6834" "#1baf7a" "#eda100" "#e87ba4" "#008300" "#6250d6" "#e34948"))
    (define categorical-dark '("#3987e5" "#d95926" "#199e70" "#c98500" "#d55181" "#008300" "#9085e9" "#e66767"))
    (define sequential '("#cde2fb" "#b7d3f6" "#9ec5f4" "#86b6ef" "#6da7ec" "#5598e7" "#3987e5" "#2a78d6"
                         "#256abf" "#1c5cab" "#184f95"))

    (define (css-rules mode)
      (let* ((dark? (eq? mode 'dark))
             (surface (if dark? "#1a1a19" "#fcfcfb"))
             (ink1 (if dark? "#f0efec" "#0b0b0b"))
             (ink2 (if dark? "#c3c2b7" "#52514e"))
             (ink3 "#898781")
             (grid (if dark? "#2c2c2a" "#e1e0d9"))
             (axis (if dark? "#383835" "#c3c2b7"))
             (cats (if dark? categorical-dark categorical-light)))
        (append
         (list (cons "viz-bg" (string-append "fill:" surface))
               (cons "viz-t1" (string-append "fill:" ink1))
               (cons "viz-t2" (string-append "fill:" ink2))
               (cons "viz-t3" (string-append "fill:" ink3))
               (cons "viz-grid" (string-append "stroke:" grid ";stroke-width:1;fill:none"))
               (cons "viz-axis" (string-append "stroke:" axis ";stroke-width:1;fill:none"))
               (cons "viz-ref" (string-append "stroke:" ink2 ";stroke-width:1;fill:none"))
               (cons "viz-ring" (string-append "stroke:" surface ";stroke-width:2")))
         (append-map (lambda (c i)
                       (let ((k (number->string i)))
                         (list (cons (string-append "viz-s" k) (string-append "fill:" c))
                               (cons (string-append "viz-l" k)
                                     (string-append "stroke:" c ";stroke-width:2;fill:none;stroke-linejoin:round;stroke-linecap:round"))
                               (cons (string-append "viz-w" k) (string-append "fill:" c ";fill-opacity:0.12")))))
                     cats (iota 8 1))
         (map (lambda (c i) (cons (string-append "viz-q" (number->string i)) (string-append "fill:" c)))
              sequential (iota (length sequential) 1)))))

    (define (plot-css . opts)
      "Syntax: (plot-css [scope])
Library: (scm data plot)
Description: The CSS for charts on an HTML page: light colours, and dark
  ones for prefers-color-scheme: dark and for [data-theme=dark] on the
  root element (a [data-theme=light] root stays light). Charts embed the
  light sheet themselves, so this is only needed for dark mode.
Example:
  (plot-css)"
      (let ((rules (lambda (mode prefix)
                     (string-concatenate
                      (map (lambda (r) (string-append prefix "." (car r) "{" (cdr r) "}\n"))
                           (css-rules mode))))))
        (string-append
         (rules 'light "")
         "@media (prefers-color-scheme: dark) {\n"
         (rules 'dark ":root:not([data-theme=\"light\"]) ")
         "}\n"
         (rules 'dark ":root[data-theme=\"dark\"] "))))

    (define (style-sheet)
      (string-concatenate (map (lambda (r) (string-append "." (car r) "{" (cdr r) "}")) (css-rules 'light))))

    ;; --- plot specification ---------------------------------------------

    (define-record-type <plot>
      (%make-plot data specs)
      plot?
      (data plot-data)
      (specs plot-specs))

    (define (make-plot df specs)
      "Syntax: (make-plot df specs)
Library: (scm data plot)
Description: A plot of df from a list of specs (the procedure behind the
  ggplot macro, for specs built at run time).
Example:
  (make-plot df '((aes (x splg) (y n)) (geom-col)))"
      (%make-plot df specs))

    (define-syntax ggplot
      (syntax-rules ()
        ((_ df spec ...) (make-plot df (quasiquote (spec ...))))))

    (define (plot-add p . specs)
      "Syntax: (plot-add plot spec …)
Library: (scm data plot)
Description: The plot with more specs (layers, labels, …) appended.
Example:
  (plot-add p '(geom-point) '(labs (title \"x\")))"
      (%make-plot (plot-data p) (append (plot-specs p) specs)))

    (define (spec-opts spec) (if (pair? spec) (cdr spec) '()))

    (define (opt opts key dflt)
      (let ((o (find (lambda (o) (and (pair? o) (eq? (car o) key))) opts)))
        (if o (if (null? (cdr o)) #t (cadr o)) dflt)))

    (define (opt-list opts key)
      (let ((o (find (lambda (o) (and (pair? o) (eq? (car o) key))) opts)))
        (and o (cdr o))))

    (define (aes-of opts)
      (let ((a (find (lambda (o) (and (pair? o) (eq? (car o) 'aes))) opts)))
        (if a (map (lambda (p) (cons (car p) (cadr p))) (cdr a)) '())))

    (define geoms '(geom-col geom-bar geom-line geom-point geom-area geom-histogram
                    geom-boxplot geom-text geom-hline geom-vline))

    (define (find-spec specs name)
      (find (lambda (s) (and (pair? s) (eq? (car s) name))) specs))

    ;; --- text --------------------------------------------------------

    (define (text-width s size)
      (font-text-width dejavu-sans size s))

    (define (text x y s cls . attrs)
      `(text (@ (x ,(px x)) (y ,(px y)) (class ,cls) ,@attrs) ,s))

    (define (px x)
      ;; one decimal
      (let ((r (/ (round (* 10 (inexact x))) 10)))
        (if (integer? r) (number->string (exact r)) (number->string r))))

    ;; --- scales ------------------------------------------------------

    (define (nice-step span n)
      (if (<= span 0)
          1
          (let* ((raw (/ span n))
                 (mag (expt 10 (floor (/ (log raw) (log 10)))))
                 (f (/ raw mag)))
            (* mag (cond ((<= f 1) 1) ((<= f 2) 2) ((<= f 2.5) 2.5) ((<= f 5) 5) (else 10))))))

    (define (nice-ticks lo hi n)
      (let* ((step (nice-step (- hi lo) n))
             (a (* step (floor (/ lo step))))
             (b (* step (ceiling (/ hi step)))))
        (let loop ((t a) (acc '()))
          (if (> t (+ b (* step 1e-9)))
              (values (reverse acc) step a b)
              (loop (+ t step) (cons (let ((r (/ (round (* t 1e9)) 1e9))) r) acc))))))

    (define (formatter spec step)
      (cond ((procedure? spec) spec)
            ((eq? spec 'pct) (lambda (x) (fmt-pct x (if (< step 0.01) 1 0))))
            ((eq? spec 'si) (lambda (x) (fmt-si x)))
            ((eq? spec 'int) fmt-int)
            ((eq? spec 'date) (lambda (x) (day->string (day-from-number (exact (round x))))))
            (else
             (let ((d (if (>= step 1) 0 (exact (ceiling (- (/ (log step) (log 10))))))))
               (lambda (x) (fmt-num x d))))))

    ;; 20k, 2.5k, 1.2M
    (define (compact x)
      (let* ((a (abs x))
             (unit (cond ((>= a 1e9) 1e9) ((>= a 1e6) 1e6) ((>= a 1e3) 1e3) (else 1)))
             (suffix (cond ((= unit 1e9) "G") ((= unit 1e6) "M") ((= unit 1e3) "k") (else "")))
             (v (/ x unit)))
        (string-append (if (integer? (/ (round (* v 10)) 10))
                           (fmt-num v 0 #f)
                           (fmt-num v 1 #f))
                       suffix)))

    ;; full numbers while the data stays below 10,000, compact above;
    ;; year-like integer axes get no thousands separator
    (define (default-formatter data-hi step . values)
      (cond ((and (pair? values) (pair? (car values))
                  (every (lambda (v) (and (integer? v) (<= 1800 v 2200))) (car values)))
             (lambda (x) (fmt-num x 0 #f)))
            ((>= (abs data-hi) 10000) (lambda (x) (if (= x 0) "0" (compact x))))
            (else (formatter #f step))))

    (define (value-label v)
      (if (integer? v) (fmt-num v 0) (fmt-num v 1)))

    (define (discrete-value? x)
      (not (or (real? x) (day? x) (na? x))))

    (define (num x) (if (day? x) (day-number x) x))

    ;; --- layer preparation ------------------------------------------------

    ;; a prepared layer: (geom opts items), items depend on the geom:
    ;;   bars:  #(x base top fill-key label tip?)   points/text: #(x y key label)
    ;;   lines/areas: (key . ((x . y) …))   box: #(x q1 med q3 lo hi outliers)
    ;;   hline/vline: value

    (define (layer-data plot-df opts)
      (or (opt opts 'data #f) plot-df))

    (define (eval-aes df aes key)
      (let ((e (assq key aes)))
        (and e (eval-column (df-ungroup df) (cdr e)))))

    (define (vref v i) (if v (vector-ref v i) na))

    (define (prepare-layer geom opts plot-aes plot-df)
      (let* ((aes (append (aes-of opts) plot-aes))
             (df (layer-data plot-df opts))
             (n (df-nrow df))
             (xv (eval-aes df aes 'x)) (yv (eval-aes df aes 'y))
             (fv (or (eval-aes df aes 'fill) (eval-aes df aes 'color)))
             (lv (eval-aes df aes 'label))
             (gv (eval-aes df aes 'group))
             (rows (filter (lambda (i) (not (na? (vref xv i)))) (iota n))))
        (case geom
          ((geom-col geom-bar)
           (let* ((pairs (if (eq? geom 'geom-bar)
                             ;; counts per (x, fill)
                             (let ((h (make-hash-table equal?)) (order '()))
                               (for-each (lambda (i)
                                           (let ((k (cons (vref xv i) (vref fv i))))
                                             (unless (hash-table-exists? h k) (set! order (cons k order)))
                                             (hash-table-update!/default h k (lambda (c) (+ c 1)) 0)))
                                         rows)
                               (map (lambda (k) (list (car k) (cdr k) (hash-table-ref h k) na)) (reverse order)))
                             (filter-map (lambda (i) (and (not (na? (vref yv i)))
                                                          (list (vref xv i) (vref fv i) (vref yv i) (vref lv i))))
                                         rows)))
                  (position (opt opts 'position (if fv 'stack 'identity))))
             (list geom opts (stack-bars pairs position) position)))
          ((geom-histogram)
           (let* ((vals (filter real? (map (lambda (i) (vref xv i)) rows)))
                  (bins (cond ((opt opts 'binwidth #f) => (lambda (w) (stats:histogram-bins vals 'width w)))
                              ((opt opts 'bins #f) => (lambda (k) (stats:histogram-bins vals k)))
                              (else (stats:histogram-bins vals)))))
             (list geom opts
                   (map (lambda (a b c) (vector (cons a b) 0 c na na #t))
                        (vector->list (df-column bins 'from)) (vector->list (df-column bins 'to))
                        (vector->list (df-column bins 'n)))
                   'identity)))
          ((geom-point geom-text)
           (list geom opts
                 (filter-map (lambda (i) (and (not (na? (vref yv i)))
                                              (vector (vref xv i) (vref yv i) (vref fv i) (vref lv i))))
                             rows)
                 'identity))
          ((geom-line geom-area)
           (let* ((key (lambda (i) (cond (gv (vref gv i)) (fv (vref fv i)) (else 'all))))
                  (keys (delete-duplicates (map key rows)))
                  (series (map (lambda (k)
                                 (cons (if (or gv (not fv)) (if fv (vref fv (find (lambda (i) (equal? (key i) k)) rows)) na) k)
                                       (filter-map (lambda (i) (and (equal? (key i) k) (not (na? (vref yv i)))
                                                                    (cons (vref xv i) (vref yv i))))
                                                   rows)))
                               keys))
                  (position (opt opts 'position 'identity)))
             (list geom opts (if (and (eq? geom 'geom-area) (eq? position 'stack)) (stack-areas series) series)
                   position)))
          ((geom-boxplot)
           (let* ((xs (delete-duplicates (map (lambda (i) (vref xv i)) rows))))
             (list geom opts
                   (map (lambda (x)
                          (let* ((vals (filter real? (filter-map (lambda (i) (and (equal? (vref xv i) x) (vref yv i))) rows)))
                                 (q1 (stats:quantile vals 1/4)) (med (stats:quantile vals 1/2)) (q3 (stats:quantile vals 3/4))
                                 (lim (* 1.5 (- q3 q1)))
                                 (inside (filter (lambda (v) (<= (- q1 lim) v (+ q3 lim))) vals)))
                            (vector x q1 med q3 (apply min inside) (apply max inside)
                                    (remove (lambda (v) (<= (- q1 lim) v (+ q3 lim))) vals))))
                        xs)
                   'identity)))
          ((geom-hline) (list geom opts (let ((v (opt opts 'yintercept 0))) (if (list? v) v (list v))) 'identity))
          ((geom-vline) (list geom opts (let ((v (opt opts 'xintercept 0))) (if (list? v) v (list v))) 'identity))
          (else (error "ggplot: unknown geom" geom)))))

    ;; (x fill y label) rows -> bar items #(x base top fill label tip? dodge-key)
    (define (stack-bars rows position)
      (case position
        ((dodge identity)
         (map (lambda (r) (vector (car r) 0 (caddr r) (cadr r) (cadddr* r) #t)) rows))
        ((stack fill)
         (let ((tot (make-hash-table equal?)) (pos (make-hash-table equal?)) (neg (make-hash-table equal?))
               (last (make-hash-table equal?)))
           (for-each (lambda (r) (hash-table-update!/default tot (car r) (lambda (s) (+ s (abs (caddr r)))) 0)
                             (hash-table-set! last (car r) r))
                     rows)
           (map (lambda (r)
                  (let* ((x (car r))
                         (y (if (eq? position 'fill)
                                (let ((t (hash-table-ref tot x))) (if (zero? t) 0 (/ (caddr r) t)))
                                (caddr r)))
                         (table (if (< y 0) neg pos))
                         (base (hash-table-ref/default table x 0)))
                    (hash-table-set! table x (+ base y))
                    (vector x base (+ base y) (cadr r) (cadddr* r) (eq? (hash-table-ref last x) r))))
                rows)))
        (else (error "geom-col: unknown position" position))))

    (define (cadddr* r) (if (> (length r) 3) (list-ref r 3) na))

    (define (stack-areas series)
      ;; cumulative by x over the series in order
      (let ((acc (make-hash-table equal?)))
        (map (lambda (s)
               (cons (car s)
                     (map (lambda (p)
                            (let* ((b (hash-table-ref/default acc (car p) 0))
                                   (t (+ b (cdr p))))
                              (hash-table-set! acc (car p) t)
                              (list (car p) b t)))
                          (cdr s))))
             series)))

    ;; --- collecting scale domains ---------------------------------------

    (define (layer-xs layer)
      (let ((geom (car layer)) (items (caddr layer)))
        (case geom
          ((geom-col geom-bar) (map (lambda (b) (vector-ref b 0)) items))
          ((geom-histogram) (append-map (lambda (b) (list (car (vector-ref b 0)) (cdr (vector-ref b 0)))) items))
          ((geom-point geom-text) (map (lambda (p) (vector-ref p 0)) items))
          ((geom-line geom-area) (append-map (lambda (s) (map car (cdr s))) items))
          ((geom-boxplot) (map (lambda (b) (vector-ref b 0)) items))
          ((geom-vline) items)
          (else '()))))

    (define (layer-ys layer)
      (let ((geom (car layer)) (items (caddr layer)))
        (case geom
          ((geom-col geom-bar geom-histogram)
           (append-map (lambda (b) (list (vector-ref b 1) (vector-ref b 2))) items))
          ((geom-point geom-text) (map (lambda (p) (vector-ref p 1)) items))
          ((geom-line) (append-map (lambda (s) (map cdr (cdr s))) items))
          ((geom-area) (cons 0 (append-map (lambda (s) (append-map (lambda (p) (if (pair? (cdr p)) (cdr p) (list (cdr p)))) (cdr s))) items)))
          ((geom-boxplot) (append-map (lambda (b) (cons* (vector-ref b 4) (vector-ref b 5) (vector-ref b 6))) items))
          ((geom-hline) items)
          (else '()))))

    (define (layer-keys layer)
      (let ((geom (car layer)) (items (caddr layer)))
        (case geom
          ((geom-col geom-bar) (map (lambda (b) (vector-ref b 3)) items))
          ((geom-point geom-text) (map (lambda (p) (vector-ref p 2)) items))
          ((geom-line geom-area) (map car items))
          (else '()))))

    ;; --- rendering ---------------------------------------------------

    (define (bar-path a0 a1 base end round? flip?)
      ;; a: band axis pixels (a0 < a1), b: value axis pixels from base to end
      (let* ((pt (lambda (a b) (if flip? (string-append (px b) "," (px a)) (string-append (px a) "," (px b)))))
             (len (abs (- end base)))
             (r (min 4 (/ (- a1 a0) 2) len))
             (d (if (< end base) -1 1)))
        (if (or (not round?) (< r 0.5))
            (string-append "M" (pt a0 base) "L" (pt a0 end) "L" (pt a1 end) "L" (pt a1 base) "Z")
            (string-append "M" (pt a0 base)
                           "L" (pt a0 (- end (* d r)))
                           "Q" (pt a0 end) " " (pt (+ a0 r) end)
                           "L" (pt (- a1 r) end)
                           "Q" (pt a1 end) " " (pt a1 (- end (* d r)))
                           "L" (pt a1 base) "Z"))))

    (define (render p)
      (let* ((specs (plot-specs p))
             (df (plot-data p))
             (plot-aes (let ((a (find-spec specs 'aes))) (if a (map (lambda (q) (cons (car q) (cadr q))) (cdr a)) '())))
             (labs (spec-opts (or (find-spec specs 'labs) '(labs))))
             (theme (spec-opts (or (find-spec specs 'theme) '(theme))))
             (sx (spec-opts (or (find-spec specs 'scale-x) '(scale-x))))
             (sy (spec-opts (or (find-spec specs 'scale-y) '(scale-y))))
             (flip? (and (find-spec specs 'coord-flip) #t))
             (facet (find-spec specs 'facet-wrap))
             (W (opt theme 'width 720))
             (H (opt theme 'height 400))
             (fs (opt theme 'font-size 12))
             (layer-specs (filter (lambda (s) (and (pair? s) (memq (car s) geoms))) specs))
             (_ (when (null? layer-specs) (error "ggplot: no geom layer")))
             ;; facet panels: list of (label . frame)
             (panels (if facet
                         (let* ((fexpr (cadr facet))
                                (fcol (eval-column (df-ungroup df) fexpr))
                                (vals (let ((v (delete-duplicates (vector->list fcol))))
                                        (if (every (lambda (x) (or (real? x) (day? x))) v) (list-sort value<? v) v))))
                           (map (lambda (v)
                                  (cons v (df-take (df-ungroup df)
                                                   (list->vector (filter (lambda (i) (value=? (vector-ref fcol i) v))
                                                                         (iota (df-nrow df)))))))
                                vals))
                         (list (cons #f df))))
             (prepared (map (lambda (pn)
                              (cons (car pn)
                                    (map (lambda (s) (prepare-layer (car s) (spec-opts s) plot-aes (cdr pn)))
                                         layer-specs)))
                            panels))
             (all-layers (append-map cdr prepared))
             ;; x scale
             (xs (append-map layer-xs all-layers))
             (bars? (any (lambda (l) (memq (car l) '(geom-col geom-bar geom-boxplot))) all-layers))
             (x-discrete? (or bars? (any discrete-value? xs)))
             (x-levels (and x-discrete?
                            (or (opt-list sx 'levels)
                                (let ((v (delete-duplicates (remove na? xs) value=?)))
                                  (if (every (lambda (x) (or (real? x) (day? x))) v) (list-sort value<? v) v)))))
             (x-date? (and (not x-discrete?) (pair? xs) (every (lambda (x) (or (day? x) (na? x))) xs)))
             (x-lims (and (not x-discrete?)
                          (or (opt-list sx 'limits)
                              (let ((ns (map num (filter (lambda (x) (or (real? x) (day? x))) xs))))
                                (if (null? ns) '(0 1) (list (apply min ns) (apply max ns)))))))
             ;; y scale
             (ys (filter real? (append-map layer-ys all-layers)))
             (zero? (any (lambda (l) (memq (car l) '(geom-col geom-bar geom-histogram geom-area))) all-layers))
             (fill-pos? (any (lambda (l) (eq? (cadddr l) 'fill)) all-layers))
             (y-lims (or (opt-list sy 'limits)
                         (let* ((ys (if zero? (cons 0 ys) ys))
                                (lo (if (null? ys) 0 (apply min ys)))
                                (hi (if (null? ys) 1 (apply max ys))))
                           (if (= lo hi) (list (- lo 1) (+ hi 1)) (list lo hi)))))
             ;; colour keys
             (keys (delete-duplicates (remove na? (append-map layer-keys all-layers)) value=?))
             (keys (if (any (lambda (l) (memq (car l) '(geom-line geom-area))) all-layers) (remove (lambda (k) (eq? k 'all)) keys) keys))
             (_ (when (> (length keys) 8)
                  (error "ggplot: more than 8 colour groups; facet the plot or fold small groups into \"Other\"")))
             (key-index (lambda (k) (let ((i (list-index (lambda (x) (value=? x k)) keys))) (if i (+ i 1) 1))))
             (legend? (and (>= (length keys) 2) (not (eq? (opt theme 'legend 'right) 'none))))
             (legend-pos (opt theme 'legend 'right))
             (legend-title (let ((t (opt labs 'fill (opt labs 'color #f))))
                             (cond ((string? t) t)
                                   ((eq? t #f) (let ((e (or (assq 'fill plot-aes) (assq 'color plot-aes))))
                                                 (and e (symbol? (cdr e)) (symbol->string (cdr e)))))
                                   (else #f))))
             (key-label (lambda (k) (fmt-value k)))
             ;; axis titles
             (x-title (let ((t (opt labs 'x 'auto)))
                        (if (eq? t 'auto) (let ((e (assq 'x plot-aes))) (and e (symbol? (cdr e)) (symbol->string (cdr e)))) t)))
             (y-title (let ((t (opt labs 'y 'auto)))
                        (if (eq? t 'auto)
                            (let ((e (assq 'y plot-aes)))
                              (cond ((any (lambda (l) (memq (car l) '(geom-bar geom-histogram))) all-layers) "count")
                                    ((and e (symbol? (cdr e))) (symbol->string (cdr e)))
                                    (else #f)))
                            t)))
             (title (opt labs 'title #f)) (subtitle (opt labs 'subtitle #f)) (caption (opt labs 'caption #f))
             ;; value ticks
             (y-ticks+ (call-with-values (lambda () (nice-ticks (car y-lims) (cadr y-lims) 5)) list))
             (y-ticks (filter (lambda (t) (<= (- (car y-lims) 1e-9) t (+ (cadr y-lims) (* 1e-9 (abs (cadr y-lims)))))) (car y-ticks+)))
             (y-ticks (if (opt-list sy 'limits) y-ticks (car y-ticks+)))
             (y-lo (if (opt-list sy 'limits) (car y-lims) (caddr y-ticks+)))
             (y-hi (if (opt-list sy 'limits) (cadr y-lims) (cadddr y-ticks+)))
             (y-fmt (let ((f (opt sy 'labels #f)))
                      (cond (f (formatter f (cadr y-ticks+)))
                            (fill-pos? (formatter 'pct (cadr y-ticks+)))
                            (else (default-formatter (fold (lambda (y m) (max m (abs y))) 0 ys) (cadr y-ticks+))))))
             (x-ticks+ (and x-lims (call-with-values (lambda () (nice-ticks (car x-lims) (cadr x-lims) 6)) list)))
             (x-ticks (and x-ticks+ (filter (lambda (t) (<= (car x-lims) t (cadr x-lims))) (car x-ticks+))))
             (x-fmt (and x-ticks+ (let ((f (opt sx 'labels #f)))
                                    (cond (f (formatter f (cadr x-ticks+)))
                                          (x-date? (formatter 'date 1))
                                          (else (default-formatter (max (abs (car x-lims)) (abs (cadr x-lims)))
                                                                   (cadr x-ticks+)
                                                                   (filter real? xs)))))))
             (x-labels (if x-discrete? (map fmt-value x-levels) (map x-fmt x-ticks)))
             (y-labels (map y-fmt y-ticks))
             ;; the axis whose labels sit on the left and at the bottom
             (left-labels (if flip? x-labels y-labels))
             (bottom-labels (if flip? y-labels x-labels))
             (left-title (if flip? x-title y-title))
             (bottom-title (if flip? y-title x-title))
             (sfs (- fs 1))
             (left-w (fold (lambda (s m) (max m (text-width s sfs))) 0 left-labels))
             ;; layout
             (top (+ 12 (if title (+ fs 10) 0) (if subtitle (+ fs 6) 0) (if (or title subtitle) 8 0)))
             (legend-w (if (and legend? (eq? legend-pos 'right))
                           (+ 28 (fold (lambda (k m) (max m (text-width (key-label k) sfs)))
                                       (if legend-title (text-width legend-title sfs) 0) keys))
                           0))
             (legend-h (if (and legend? (eq? legend-pos 'bottom)) (+ fs 14) 0))
             (left (+ 12 (if left-title (+ fs 8) 0) left-w 8))
             (right (+ 16 legend-w
                       (if (and (pair? bottom-labels) (or flip? (not x-discrete?)) (not (and legend? (eq? legend-pos 'right))))
                           (/ (text-width (last bottom-labels) sfs) 2)
                           0)))
             (npan (length prepared))
             (ncol (if facet (opt (cddr facet) 'ncol (exact (ceiling (sqrt npan)))) 1))
             (nrow (exact (ceiling (/ npan ncol))))
             (strip (if facet (+ fs 8) 0))
             (gap 20)
             ;; bottom labels: rotate when they don't fit the band
             (avail-w (- W left right (* gap (- ncol 1))))
             (pw (/ avail-w ncol))
             (band-px (if (and x-discrete? (not flip?)) (/ pw (max 1 (length x-levels))) 1e9))
             (rotate? (and (not flip?) x-discrete?
                           (> (fold (lambda (s m) (max m (text-width s sfs))) 0 bottom-labels) (- band-px 4))))
             (bottom-lab-h (if rotate?
                               (+ 8 (* 0.7 (fold (lambda (s m) (max m (text-width s sfs))) 0 bottom-labels)))
                               (+ sfs 8)))
             (bottom (+ 8 bottom-lab-h (if bottom-title (+ fs 8) 0) (if caption (+ fs 6) 0) legend-h 6))
             (avail-h (- H top bottom (* (+ gap strip) (- nrow 1)) strip))
             (ph (/ avail-h nrow))
             (out '()))
        (define (emit! x) (set! out (cons x out)))
        ;; background and titles
        (emit! `(rect (@ (x 0) (y 0) (width ,W) (height ,H) (class "viz-bg"))))
        (let ((ty (+ 12 fs)))
          (when title (emit! (text left ty title "viz-t1" '(font-size "15") '(font-weight "bold"))))
          (when subtitle (emit! (text left (+ ty (if title (+ fs 6) 0)) subtitle "viz-t2" `(font-size ,(number->string fs))))))
        (when caption
          (emit! (text left (- H 8 legend-h) caption "viz-t3" `(font-size ,(number->string (- fs 2))))))
        ;; panels
        (for-each
         (lambda (pn k)
           (let* ((col (modulo k ncol)) (row (quotient k ncol))
                  (x0 (+ left (* col (+ pw gap))))
                  (y0 (+ top strip (* row (+ ph gap strip))))
                  ;; band axis length / value axis
                  (alen (if flip? ph pw))
                  (vlo (if flip? x0 (+ y0 ph)))            ; pixel of y-lo
                  (vhi (if flip? (+ x0 pw) y0))            ; pixel of y-hi
                  (vmap (lambda (v) (let ((v (if (opt sy 'log10 #f) (/ (log (max v 1e-9)) (log 10)) v)))
                                      (+ vlo (* (- vhi vlo) (/ (- v y-lo) (- y-hi y-lo)))))))
                  (nlev (if x-discrete? (max 1 (length x-levels)) 1))
                  (band (/ alen nlev))
                  (amap (lambda (x) ; centre pixel along the band axis
                          (if x-discrete?
                              (let ((i (or (list-index (lambda (l) (value=? l x)) x-levels) 0)))
                                (if flip? (+ y0 (* band (+ i 0.5))) (+ x0 (* band (+ i 0.5)))))
                              (let ((a (if flip? (+ y0 ph) x0)) (b (if flip? y0 (+ x0 pw))))
                                (+ a (* (- b a) (/ (- (num x) (car x-lims)) (max 1e-12 (- (cadr x-lims) (car x-lims))))))))))
                  (pt (lambda (a b) (if flip? (list b a) (list a b))))
                  (layers (cdr pn)))
             ;; strip
             (when facet
               (emit! (text x0 (- y0 6) (fmt-value (car pn)) "viz-t2" `(font-size ,(number->string fs)) '(font-weight "bold"))))
             ;; grid on the value axis
             (for-each (lambda (t)
                         (let ((v (vmap t)))
                           (emit! (if flip?
                                      `(line (@ (x1 ,(px v)) (y1 ,(px y0)) (x2 ,(px v)) (y2 ,(px (+ y0 ph))) (class "viz-grid")))
                                      `(line (@ (x1 ,(px x0)) (y1 ,(px v)) (x2 ,(px (+ x0 pw))) (y2 ,(px v)) (class "viz-grid")))))))
                       y-ticks)
             ;; grid on a continuous x axis
             (when (and x-ticks (not x-discrete?))
               (for-each (lambda (t)
                           (let ((a (amap t)))
                             (emit! (if flip?
                                        `(line (@ (x1 ,(px x0)) (y1 ,(px a)) (x2 ,(px (+ x0 pw))) (y2 ,(px a)) (class "viz-grid")))
                                        `(line (@ (x1 ,(px a)) (y1 ,(px y0)) (x2 ,(px a)) (y2 ,(px (+ y0 ph))) (class "viz-grid")))))))
                         x-ticks))
             ;; baseline at 0 (or the low end)
             (let* ((b (vmap (if (<= y-lo 0 y-hi) 0 y-lo))))
               (emit! (if flip?
                          `(line (@ (x1 ,(px b)) (y1 ,(px y0)) (x2 ,(px b)) (y2 ,(px (+ y0 ph))) (class "viz-axis")))
                          `(line (@ (x1 ,(px x0)) (y1 ,(px b)) (x2 ,(px (+ x0 pw))) (y2 ,(px b)) (class "viz-axis"))))))
             ;; value tick labels (left column / bottom row only)
             (when (if flip? (or (= row (- nrow 1)) (>= (+ k ncol) npan)) (= col 0))
               (for-each (lambda (t s)
                           (let ((v (vmap t)))
                             (emit! (if flip?
                                        (text v (+ y0 ph sfs 6) s "viz-t3" '(text-anchor "middle") `(font-size ,(number->string sfs)))
                                        (text (- x0 8) (+ v (* 0.35 sfs)) s "viz-t3" '(text-anchor "end") `(font-size ,(number->string sfs)))))))
                         y-ticks y-labels))
             ;; band / x tick labels
             (when (if flip? (= col 0) (or (= row (- nrow 1)) (>= (+ k ncol) npan)))
               (for-each (lambda (x s)
                           (let ((a (amap x)))
                             (emit! (cond
                                     (flip? (text (- x0 8) (+ a (* 0.35 sfs)) s "viz-t2" '(text-anchor "end") `(font-size ,(number->string sfs))))
                                     (rotate? (let ((ty (+ y0 ph 10)))
                                                `(text (@ (x ,(px a)) (y ,(px ty)) (class "viz-t2") (text-anchor "end")
                                                          (font-size ,(number->string sfs))
                                                          (transform ,(string-append "rotate(-40 " (px a) " " (px ty) ")")))
                                                       ,s)))
                                     (else (text a (+ y0 ph sfs 6) s "viz-t2" '(text-anchor "middle") `(font-size ,(number->string sfs))))))))
                         (if x-discrete? x-levels x-ticks)
                         (if x-discrete? x-labels (map x-fmt x-ticks))))
             ;; layers
             (for-each
              (lambda (layer)
                (let ((geom (car layer)) (lopts (cadr layer)) (items (caddr layer)) (position (cadddr layer)))
                  (case geom
                    ((geom-col geom-bar geom-histogram)
                     (let* ((dodge? (eq? position 'dodge))
                            (dkeys (if dodge? keys '()))
                            (nd (max 1 (length dkeys)))
                            (thick (min 24 (* 0.8 (/ band nd))))
                            (show-labels? (opt lopts 'labels #f)))
                       (for-each
                        (lambda (b)
                          (let* ((x (vector-ref b 0))
                                 (key (vector-ref b 3))
                                 (span (if (pair? x)
                                           (let ((a (amap (car x))) (c (amap (cdr x))))
                                             (list (+ (min a c) 1) (- (max a c) 1)))
                                           (let* ((c (amap x))
                                                  (c (if dodge?
                                                         (+ c (* thick (- (- (key-index key) 1) (/ (- nd 1) 2))))
                                                         c))
                                                  (hw (/ (- thick (if dodge? 2 0)) 2)))
                                             (list (- c hw) (+ c hw)))))
                                 (base (vmap (vector-ref b 1)))
                                 (top-v (vector-ref b 2))
                                 (end0 (vmap top-v))
                                 (tip? (vector-ref b 5))
                                 ;; 2px surface gap between stacked segments
                                 (end (if (and (not tip?) (memq position '(stack fill)))
                                          (+ end0 (* 2 (if (< end0 base) 1 -1)))
                                          end0))
                                 (cls (string-append "viz-s" (number->string (if key (key-index key) 1))))
                                 (val (- top-v (vector-ref b 1)))
                                 (tip (string-append (if (pair? x) (string-append (fmt-value (car x)) "–" (fmt-value (cdr x))) (fmt-value x))
                                                     (if (and key (not (na? key))) (string-append ", " (fmt-value key)) "")
                                                     ": " (if (or (opt sy 'labels #f) fill-pos?) (y-fmt val) (value-label val)))))
                            (emit! `(path (@ (d ,(bar-path (car span) (cadr span) base end tip? flip?)) (class ,cls))
                                          (title ,tip)))
                            (when (and show-labels? tip?)
                              (let* ((s (cond ((not (na? (vector-ref b 4))) (fmt-value (vector-ref b 4)))
                                              ((or (opt sy 'labels #f) fill-pos?) (y-fmt top-v))
                                              (else (value-label top-v))))
                                     (a (/ (+ (car span) (cadr span)) 2))
                                     (out (if (< end0 base) -1 1)))
                                (emit! (if flip?
                                           (text (+ end0 (* out 6)) (+ a (* 0.35 sfs)) s "viz-t2"
                                                 `(text-anchor ,(if (> out 0) "start" "end")) `(font-size ,(number->string sfs)))
                                           (text a (+ end0 (* out (if (< out 0) 6 (+ sfs 2)))) s "viz-t2"
                                                 '(text-anchor "middle") `(font-size ,(number->string sfs)))))))))
                        items)))
                    ((geom-line geom-area)
                     (for-each
                      (lambda (s)
                        (let* ((k (car s))
                               (i (number->string (if (and (not (na? k)) (memv* k keys)) (key-index k) 1)))
                               (pts (list-sort (lambda (p q) (value<? (car p) (car q))) (cdr s)))
                               (stacked? (and (pair? pts) (pair? (cdr (car pts)))))
                               (yv (lambda (p) (if stacked? (caddr p) (cdr p))))
                               (bv (lambda (p) (if stacked? (cadr p) 0)))
                               (coords (map (lambda (p) (pt (amap (car p)) (vmap (yv p)))) pts))
                               (d (string-append "M" (string-join (map (lambda (c) (string-append (px (car c)) "," (px (cadr c)))) coords) "L"))))
                          (when (and (eq? geom 'geom-area) (pair? pts))
                            (let* ((lower (reverse (map (lambda (p) (pt (amap (car p)) (vmap (bv p)))) pts)))
                                   (poly (string-append d "L" (string-join (map (lambda (c) (string-append (px (car c)) "," (px (cadr c)))) lower) "L") "Z")))
                              (emit! `(path (@ (d ,poly) (class ,(string-append "viz-w" i)))))))
                          (when (pair? pts)
                            (emit! `(path (@ (d ,d) (class ,(string-append "viz-l" i)))
                                          (title ,(if (na? k) "" (fmt-value k))))))))
                      items))
                    ((geom-point)
                     (for-each
                      (lambda (p)
                        (let* ((c (pt (amap (vector-ref p 0)) (vmap (vector-ref p 1))))
                               (k (vector-ref p 2))
                               (cls (string-append "viz-s" (number->string (if (na? k) 1 (key-index k))) " viz-ring")))
                          (emit! `(circle (@ (cx ,(px (car c))) (cy ,(px (cadr c))) (r "4.5") (class ,cls))
                                          (title ,(string-append (fmt-value (vector-ref p 0)) ", " (y-fmt (vector-ref p 1))
                                                                 (if (na? k) "" (string-append " (" (fmt-value k) ")"))))))))
                      items))
                    ((geom-text)
                     (for-each
                      (lambda (p)
                        (let ((c (pt (amap (vector-ref p 0)) (vmap (vector-ref p 1)))))
                          (emit! (text (car c) (- (cadr c) 6) (fmt-value (vector-ref p 3)) "viz-t2"
                                       '(text-anchor "middle") `(font-size ,(number->string sfs))))))
                      items))
                    ((geom-boxplot)
                     (for-each
                      (lambda (b)
                        (let* ((a (amap (vector-ref b 0)))
                               (hw (/ (min 24 (* 0.6 band)) 2))
                               (seg (lambda (a1 v1 a2 v2 cls)
                                      (let ((p1 (pt a1 (vmap v1))) (p2 (pt a2 (vmap v2))))
                                        `(line (@ (x1 ,(px (car p1))) (y1 ,(px (cadr p1))) (x2 ,(px (car p2))) (y2 ,(px (cadr p2))) (class ,cls)))))))
                          (emit! (seg a (vector-ref b 4) a (vector-ref b 1) "viz-ref"))
                          (emit! (seg a (vector-ref b 3) a (vector-ref b 5) "viz-ref"))
                          (emit! `(path (@ (d ,(bar-path (- a hw) (+ a hw) (vmap (vector-ref b 1)) (vmap (vector-ref b 3)) #f flip?))
                                           (class "viz-w1"))))
                          (emit! (seg (- a hw) (vector-ref b 2) (+ a hw) (vector-ref b 2) "viz-l1"))
                          (for-each (lambda (o) (let ((c (pt a (vmap o))))
                                                  (emit! `(circle (@ (cx ,(px (car c))) (cy ,(px (cadr c))) (r "3") (class "viz-s1 viz-ring"))))))
                                    (vector-ref b 6))
                          (emit! `(title ,(string-append (fmt-value (vector-ref b 0)) ": median " (y-fmt (vector-ref b 2)))))))
                      items))
                    ((geom-hline)
                     (for-each (lambda (v)
                                 (let ((b (vmap v)))
                                   (emit! (if flip?
                                              `(line (@ (x1 ,(px b)) (y1 ,(px y0)) (x2 ,(px b)) (y2 ,(px (+ y0 ph))) (class "viz-ref")))
                                              `(line (@ (x1 ,(px x0)) (y1 ,(px b)) (x2 ,(px (+ x0 pw))) (y2 ,(px b)) (class "viz-ref")))))))
                               items))
                    ((geom-vline)
                     (for-each (lambda (v)
                                 (let ((a (amap v)))
                                   (emit! (if flip?
                                              `(line (@ (x1 ,(px x0)) (y1 ,(px a)) (x2 ,(px (+ x0 pw))) (y2 ,(px a)) (class "viz-ref")))
                                              `(line (@ (x1 ,(px a)) (y1 ,(px y0)) (x2 ,(px a)) (y2 ,(px (+ y0 ph))) (class "viz-ref")))))))
                               items)))))
              layers)))
         prepared (iota npan))
        ;; axis titles
        (when left-title
          (let ((cy (+ top (/ (- H top bottom) 2))) (cx (+ 12 fs)))
            (emit! `(text (@ (x ,(px cx)) (y ,(px cy)) (class "viz-t2") (text-anchor "middle")
                             (font-size ,(number->string sfs))
                             (transform ,(string-append "rotate(-90 " (px cx) " " (px cy) ")")))
                          ,left-title))))
        (when bottom-title
          (emit! (text (+ left (/ (- W left right) 2)) (- H 8 legend-h (if caption (+ fs 6) 0)) bottom-title "viz-t2"
                       '(text-anchor "middle") `(font-size ,(number->string sfs)))))
        ;; legend
        (when legend?
          (let ((line-legend? (every (lambda (l) (memq (car l) '(geom-line geom-point))) all-layers)))
            (define (swatch x y i)
              (let ((k (number->string i)))
                (if line-legend?
                    `(g (line (@ (x1 ,(px x)) (y1 ,(px (+ y 5))) (x2 ,(px (+ x 14))) (y2 ,(px (+ y 5))) (class ,(string-append "viz-l" k))))
                        (circle (@ (cx ,(px (+ x 7))) (cy ,(px (+ y 5))) (r "3.5") (class ,(string-append "viz-s" k " viz-ring")))))
                    `(rect (@ (x ,(px x)) (y ,(px y)) (width "10") (height "10") (rx "2") (class ,(string-append "viz-s" k)))))))
            (if (eq? legend-pos 'bottom)
                (let loop ((ks keys) (x left) (i 1))
                  (unless (null? ks)
                    (let ((y (- H 6 (+ fs 4))))
                      (emit! (swatch x y i))
                      (emit! (text (+ x 18) (+ y 9) (key-label (car ks)) "viz-t2" `(font-size ,(number->string sfs))))
                      (loop (cdr ks) (+ x 30 (text-width (key-label (car ks)) sfs)) (+ i 1)))))
                (let ((x (- W 16 legend-w -12)) (y0 (+ top 4)))
                  (when legend-title
                    (emit! (text x (+ y0 9) legend-title "viz-t2" `(font-size ,(number->string sfs)) '(font-weight "bold"))))
                  (for-each (lambda (k i)
                              (let ((y (+ y0 (if legend-title (+ sfs 10) 0) (* (- i 1) (+ sfs 8)))))
                                (emit! (swatch x y i))
                                (emit! (text (+ x 18) (+ y 9) (key-label k) "viz-t2" `(font-size ,(number->string sfs))))))
                            keys (iota (length keys) 1))))))
        `(svg (@ (xmlns "http://www.w3.org/2000/svg") (width ,W) (height ,H)
                 (viewBox ,(string-append "0 0 " (number->string W) " " (number->string H)))
                 (font-family "DejaVu Sans, Verdana, sans-serif") (role "img")
                 (aria-label ,(or title "chart")))
              (style ,(raw (style-sheet)))
              ,@(reverse out))))

    (define (memv* k keys) (any (lambda (x) (value=? x k)) keys))

    (define (plot->svg p)
      "Syntax: (plot->svg plot)
Library: (scm data plot)
Description: Renders the plot to SVG as SXML (with its style sheet
  embedded), for inline use in (scm html builder) pages.
Example:
  (html->string (plot->svg p))"
      (render p))

    (define (plot->svg-string p)
      "Syntax: (plot->svg-string plot)
Library: (scm data plot)
Description: The plot as SVG text (a standalone .svg document).
Example:
  (plot->svg-string p)"
      (string-append "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" (html->string (render p))))

    (define (plot->png p . scale)
      "Syntax: (plot->png plot [scale])
Library: (scm data plot)
Description: The plot as a PNG bytevector, rendered at scale (default 2,
  for sharp output on high-resolution screens and in documents).
Example:
  (plot->png p)"
      (svg->png (render p) (list (cons 'scale (if (pair? scale) (car scale) 2)))))

    (define (plot->pdf p . options)
      "Syntax: (plot->pdf plot [options])
Library: (scm data plot)
Description: The plot as a one-page PDF bytevector, drawn as vectors with
  embedded text. A pixel of the plot is 0.75 point (as in CSS) unless
  options, an alist as for svg->pdf of (scm svg pdf), give (width . pt)
  or (height . pt); (margin . pt) adds a margin, (title . s) sets the
  document title.
Example:
  (plot->pdf p '((width . 400)))"
      (let* ((options (if (pair? options) (car options) '()))
             (svg (render p)))
        (let-values (((w h) (svg-size svg)))
          (svg->pdf svg (if (or (assq 'width options) (assq 'height options))
                            options
                            (cons (cons 'width (* 0.75 w)) options))))))

    (define (save-plot p path . scale)
      "Syntax: (save-plot plot path [scale])
Library: (scm data plot)
Description: Writes the plot to path as SVG, PNG or PDF, chosen by the
  extension (.svg, .png or .pdf); scale applies to PNG.
Example:
  (save-plot p \"points.png\")"
      (define (write-bytes bv)
        (call-with-port (open-binary-output-file path)
          (lambda (o) (write-bytevector bv o))))
      (cond ((string-suffix-ci? ".svg" path)
             (call-with-output-file path (lambda (o) (write-string (plot->svg-string p) o))))
            ((string-suffix-ci? ".png" path) (write-bytes (apply plot->png p scale)))
            ((string-suffix-ci? ".pdf" path) (write-bytes (plot->pdf p)))
            (else (error "save-plot: use a .svg, .png or .pdf file name" path))))

    ;; --- quick charts ---------------------------------------------------

    (define (bar-chart df x y . opts)
      "Syntax: (bar-chart df x y [fill [title]])
Library: (scm data plot)
Description: A bar chart of column y per x (dodged by fill when given;
  horizontal bars when there are many or long categories).
Example:
  (bar-chart df 'splg 'points 'model \"Points\")"
      (let* ((fill (and (pair? opts) (car opts)))
             (title (and (pair? opts) (pair? (cdr opts)) (cadr opts)))
             (labels (map fmt-value (vector->list (df-column df x))))
             (flip? (or (> (length (delete-duplicates labels)) 12)
                        (> (fold (lambda (s m) (max m (string-length s))) 0 labels) 10))))
        (make-plot df (append (list (cons 'aes (append (list (list 'x x) (list 'y y)) (if fill (list (list 'fill fill)) '())))
                                    (list 'geom-col (list 'position (if fill 'dodge 'identity))))
                              (if flip? '((coord-flip)) '())
                              (if title (list (list 'labs (list 'title title))) '())))))

    (define (line-chart df x y . opts)
      "Syntax: (line-chart df x y [color [title]])
Library: (scm data plot)
Description: Lines of y over x, one per value of color.
Example:
  (line-chart df 'year 'cases 'kanton)"
      (let ((color (and (pair? opts) (car opts)))
            (title (and (pair? opts) (pair? (cdr opts)) (cadr opts))))
        (make-plot df (append (list (cons 'aes (append (list (list 'x x) (list 'y y)) (if color (list (list 'color color)) '())))
                                    '(geom-line) '(geom-point))
                              (if title (list (list 'labs (list 'title title))) '())))))

    (define (scatter-plot df x y . opts)
      (let ((color (and (pair? opts) (car opts))))
        (make-plot df (list (cons 'aes (append (list (list 'x x) (list 'y y)) (if color (list (list 'color color)) '())))
                            '(geom-point)))))

    (define (histogram df x . opts)
      "Syntax: (histogram df x [bins])
Library: (scm data plot)
Description: A histogram of column x.
Example:
  (histogram df 'age 20)"
      (make-plot df (list (list 'aes (list 'x x))
                          (if (pair? opts) (list 'geom-histogram (list 'bins (car opts))) '(geom-histogram)))))))
