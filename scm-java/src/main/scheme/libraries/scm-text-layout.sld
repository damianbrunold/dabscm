;; (scm text layout) — breaking paragraphs of styled text into lines.
;;
;; A paragraph is a list of runs: pieces of text in one style, each with
;; a procedure that measures its text and the size, ascent and descent of
;; its font. layout-paragraph breaks them into lines for a given width the
;; way a browser does with white-space: pre-wrap and overflow-wrap:
;; break-word: spaces are kept (except those at the end of a soft line
;; break, which hang), "\n" breaks the line, a word wider than the line
;; is broken between characters. Line heights follow CSS: a line box is
;; as tall as its tallest inline box, each box being its font's ascent
;; plus descent plus half the leading above and below; a strut (the
;; paragraph's own font) takes part as if it were on every line.
;;
;; Measuring is the caller's: (scm pdf)'s pdf-text-width, (scm truetype)'s
;; font-text-width or anything else, in any unit, so the same layout
;; serves a PDF, an SVG or a slide in a presentation.

(define-library (scm text layout)
  (import (scheme base)
          (scheme char))
  (export make-text-run
          text-run?
          text-run-text
          text-run-size
          text-run-data
          layout-paragraph
          line-items
          line-width
          line-height
          line-baseline
          line-hard-break?
          item-x
          item-text
          item-width
          item-run
          layout-height)
  (begin

    (define-record-type text-run
      (%make-text-run text measure size ascent descent data)
      text-run?
      (text text-run-text)
      (measure text-run-measure)
      (size text-run-size)
      (ascent text-run-ascent)
      (descent text-run-descent)
      (data text-run-data))

    (define (make-text-run text measure size ascent descent . data)
      "Syntax: (make-text-run text measure size ascent descent [data])
Library: (scm text layout)
Description: A run of text in one style. (measure string) returns the
  width of string in this style; size is the font size, ascent and
  descent the font's extent above and below the baseline (positive), all
  in the same unit as the widths. data is anything the caller wants back
  with the run's pieces (its colour, font, link ...).
Example:
  (make-text-run \"Hallo\" (lambda (s) (pdf-text-width f 12 s)) 12 11.6 2.9 'black)"
      (%make-text-run text measure size ascent descent (if (pair? data) (car data) #f)))

    (define-record-type line
      (make-line items width height baseline hard-break?)
      line?
      (items line-items)
      (width line-width)
      (height line-height)
      (baseline line-baseline)
      (hard-break? line-hard-break?))

    (define-record-type item
      (make-item x text width run)
      item?
      (x item-x)
      (text item-text)
      (width item-width)
      (run item-run))

    ;; --- tokens ---------------------------------------------------------
    ;; (word . parts) | (space . parts) | (newline . run), where parts are
    ;; (run . string) in order.

    (define (char-kind c)
      (cond ((char=? c #\newline) 'newline)
            ((char=? c #\space) 'space)
            (else 'word)))

    ;; Pieces of one run: (kind run . string) with kind word, space or
    ;; newline (one per newline character).
    (define (run-pieces run)
      (let ((s (text-run-text run)))
        (let loop ((i 0) (start 0) (kind #f) (acc '()))
          (let ((flush (lambda ()
                         (if (and kind (> i start) (not (eq? kind 'newline)))
                             (cons (cons kind (cons run (substring s start i))) acc)
                             acc))))
            (if (= i (string-length s))
                (reverse (flush))
                (let ((k (char-kind (string-ref s i))))
                  (cond
                    ((eq? k 'newline)
                     (loop (+ i 1) (+ i 1) #f
                           (cons (cons 'newline (cons run "")) (flush))))
                    ((eq? k kind) (loop (+ i 1) start kind acc))
                    (else (loop (+ i 1) i k (flush))))))))))

    ;; Joins neighbouring pieces of the same kind (across runs) into
    ;; tokens.
    (define (tokens runs)
      (let loop ((ps (apply append (map run-pieces runs))) (acc '()))
        (cond
          ((null? ps) (reverse acc))
          ((eq? (car (car ps)) 'newline)
           (loop (cdr ps) (cons (cons 'newline (cadr (car ps))) acc)))
          ((and (pair? acc) (eq? (car (car acc)) (car (car ps))))
           (loop (cdr ps)
                 (cons (cons (car (car acc))
                             (append (cdr (car acc)) (list (cdr (car ps)))))
                       (cdr acc))))
          (else
           (loop (cdr ps) (cons (list (car (car ps)) (cdr (car ps))) acc))))))

    (define (part-width part) ((text-run-measure (car part)) (cdr part)))

    (define (parts-width parts)
      (let loop ((ps parts) (w 0))
        (if (null? ps) w (loop (cdr ps) (+ w (part-width (car ps)))))))

    ;; Splits word parts so that the first piece fits in width (at least
    ;; one character). Returns (fitting . rest), rest possibly '().
    (define (split-word parts width)
      (let loop ((ps parts) (used 0) (taken '()))
        (if (null? ps)
            (cons (reverse taken) '())
            (let* ((run (car (car ps)))
                   (s (cdr (car ps)))
                   (w (part-width (car ps))))
              (if (<= (+ used w) width)
                  (loop (cdr ps) (+ used w) (cons (car ps) taken))
                  ;; The most characters of this part that fit.
                  (let chars ((n (string-length s)))
                    (cond
                      ((and (= n 1) (null? taken))
                       (cons (list (cons run (substring s 0 1)))
                             (cons (cons run (substring s 1 (string-length s))) (cdr ps))))
                      ((or (= n 0)
                           (<= (+ used ((text-run-measure run) (substring s 0 n))) width))
                       (if (= n 0)
                           (cons (reverse taken) ps)
                           (cons (reverse (cons (cons run (substring s 0 n)) taken))
                                 (cons (cons run (substring s n (string-length s))) (cdr ps)))))
                      (else (chars (- n 1))))))))))

    ;; --- heights --------------------------------------------------------

    ;; (above . below) of a run's inline box around the baseline.
    (define (box-extent run factor)
      (let* ((a (text-run-ascent run))
             (d (text-run-descent run))
             (half-leading (/ (- (* factor (text-run-size run)) (+ a d)) 2)))
        (cons (+ a half-leading) (+ d half-leading))))

    (define (line-metrics runs strut factor)
      (let loop ((rs (if strut (cons strut runs) runs)) (above 0) (below 0))
        (if (null? rs)
            (values (+ above below) above)
            (let ((e (box-extent (car rs) factor)))
              (loop (cdr rs) (max above (car e)) (max below (cdr e)))))))

    ;; --- breaking -------------------------------------------------------
    ;; A raw line: (tokens hard? last-run): tokens are words and spaces.

    (define (break-lines toks width)
      (let loop ((ts toks) (line '()) (w 0) (pending '()) (lines '()) (last-run #f))
        (define (finish hard? next-lines)
          (cons (list (reverse line) hard? last-run) next-lines))
        (cond
          ((null? ts)
           (reverse (finish #f lines)))
          (else
           (let* ((t (car ts)) (kind (car t)))
             (cond
               ((eq? kind 'newline)
                (loop (cdr ts) '() 0 '() (finish #t lines) (cdr t)))
               ((eq? kind 'space)
                (loop (cdr ts) line w (append pending (list t)) lines
                      (car (car (cdr t)))))
               (else                       ; a word
                (let* ((sw (apply + (map (lambda (s) (parts-width (cdr s))) pending)))
                       (ww (parts-width (cdr t)))
                       (run (car (car (cdr t)))))
                  (cond
                    ((<= (+ w sw ww) width)
                     (loop (cdr ts) (cons t (append (reverse pending) line))
                           (+ w sw ww) '() lines run))
                    ((pair? line)
                     ;; A soft break: the pending spaces hang at the end.
                     (loop ts '() 0 '() (finish #f lines) last-run))
                    (else
                     ;; Too wide on a line of its own: break it.
                     (let* ((avail (- width sw))
                            (split (split-word (cdr t) (max avail 0))))
                       (if (null? (cdr split))
                           (loop (cdr ts) (cons t (append (reverse pending) line))
                                 (+ w sw ww) '() lines run)
                           (loop (cons (cons 'word (cdr split)) (cdr ts))
                                 '() 0 '()
                                 (cons (list (reverse (cons (cons 'word (car split))
                                                            (append (reverse pending) line)))
                                             #f run)
                                       lines)
                                 run)))))))))))))

    ;; --- placing --------------------------------------------------------

    (define (layout-paragraph runs width . opts)
      "Syntax: (layout-paragraph runs width [options])
Library: (scm text layout)
Description: Breaks the runs (see make-text-run) into lines no wider
  than width and returns the lines, each with its items (pieces of text
  with their x offset from the line start, width and run), natural
  width, height, baseline (distance from the line's top) and whether it
  ended with \"\\n\". options is an alist: (align . left | center | right
  | justify), (line-height . factor) (default 1.2, times each run's
  size), (strut . run) a run for the paragraph's own font, which sets
  the minimum line height (as in CSS). Justified lines (all but the
  last and those ending with \"\\n\") stretch their spaces; their items
  are single words. An empty paragraph gives one empty line.
Example:
  (for-each (lambda (line) ...) (layout-paragraph runs 400 '((align . justify))))"
      (let* ((opts (if (pair? opts) (car opts) '()))
             (opt (lambda (k d) (let ((p (assq k opts))) (if p (cdr p) d))))
             (align (opt 'align 'left))
             (factor (opt 'line-height 6/5))
             (strut (opt 'strut #f))
             (raw (break-lines (tokens runs) width))
             (n (length raw)))
        (let loop ((rs raw) (i 0) (acc '()))
          (if (null? rs)
              (reverse acc)
              (let* ((toks (car (car rs)))
                     (hard? (cadr (car rs)))
                     (last-run (caddr (car rs)))
                     (word-runs (apply append
                                       (map (lambda (t) (if (eq? (car t) 'word)
                                                            (map car (cdr t))
                                                            '()))
                                            toks)))
                     (runs-here (if (null? word-runs)
                                    (if last-run (list last-run)
                                        (if (pair? runs) (list (car runs)) '()))
                                    word-runs))
                     (natural (apply + (map (lambda (t) (parts-width (cdr t))) toks)))
                     (gaps (let count ((ts toks) (seen-word #f) (k 0))
                             ;; spaces between words (not leading ones)
                             (cond ((null? ts) k)
                                   ((eq? (car (car ts)) 'word) (count (cdr ts) #t k))
                                   ((and seen-word (pair? (cdr ts))) (count (cdr ts) seen-word (+ k 1)))
                                   (else (count (cdr ts) seen-word k)))))
                     (justify? (and (eq? align 'justify) (not hard?) (< i (- n 1)) (> gaps 0)))
                     (free (- width natural))
                     (start (case align
                              ((center) (/ free 2))
                              ((right) free)
                              (else 0)))
                     (extra (if justify? (/ free gaps) 0)))
                (call-with-values
                  (lambda () (line-metrics runs-here strut factor))
                  (lambda (height baseline)
                    (loop (cdr rs) (+ i 1)
                          (cons (make-line (place toks start extra justify?)
                                           natural height baseline hard?)
                                acc)))))))))

    ;; Items of a line: word parts at their x; when not justifying,
    ;; neighbouring parts of the same run (spaces between them included)
    ;; become one item.
    (define (place toks start extra justify?)
      (let loop ((ts toks) (x start) (seen-word #f) (items '()))
        (if (null? ts)
            (reverse items)
            (let ((t (car ts)))
              (if (eq? (car t) 'space)
                  (let ((w (parts-width (cdr t))))
                    (if (and (not justify?) seen-word (pair? items))
                        ;; join the spaces onto the previous item for now
                        (loop (cdr ts) (+ x w) seen-word
                              (append-to-last items (cdr t) w))
                        (loop (cdr ts)
                              (+ x w (if (and justify? seen-word (pair? (cdr ts))) extra 0))
                              seen-word items)))
                  (let parts ((ps (cdr t)) (x x) (items items))
                    (if (null? ps)
                        (loop (cdr ts) x #t items)
                        (let ((w (part-width (car ps))))
                          (parts (cdr ps) (+ x w)
                                 (if (and (not justify?) (pair? items)
                                          (eq? (item-run (car items)) (car (car ps)))
                                          (= (+ (item-x (car items)) (item-width (car items))) x))
                                     (cons (make-item (item-x (car items))
                                                      (string-append (item-text (car items)) (cdr (car ps)))
                                                      (+ (item-width (car items)) w)
                                                      (car (car ps)))
                                           (cdr items))
                                     (cons (make-item x (cdr (car ps)) w (car (car ps))) items)))))))))))

    ;; Adds space parts to the last item when they are in its run (else
    ;; leaves the items alone: the gap stays a gap).
    (define (append-to-last items space-parts w)
      (let ((last (car items)))
        (if (let all ((ps space-parts))
              (or (null? ps) (and (eq? (car (car ps)) (item-run last)) (all (cdr ps)))))
            (cons (make-item (item-x last)
                             (apply string-append (item-text last) (map cdr space-parts))
                             (+ (item-width last) w)
                             (item-run last))
                  (cdr items))
            items)))

    (define (layout-height lines)
      "Syntax: (layout-height lines)
Library: (scm text layout)
Description: The total height of lines from layout-paragraph."
      (apply + (map line-height lines)))))
