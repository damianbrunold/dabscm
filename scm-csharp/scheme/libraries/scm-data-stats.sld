(define-library (scm data stats)
  (import (scheme base)
          (scheme inexact)
          (srfi 1)
          (srfi 69)
          (srfi 132)
          (scm data core)
          (scm data frame))
  (export sum
          mean
          weighted-mean
          median
          quantile
          var
          sd
          iqr
          value-range
          cumsum
          ranks
          zscore
          cov
          cor
          pct-change
          freq
          crosstab
          histogram-bins
          lm-simple)
  (begin

    ;; ================================================================
    ;; (scm data stats) — descriptive statistics on lists or vectors of
    ;; numbers (usable without data frames). na values are skipped.
    ;; var/sd use n-1 (sample), quantile uses R's default (type 7).
    ;; freq and crosstab return data frames.
    ;; ================================================================

    (define (values-of xs)
      (let ((l (if (vector? xs) (vector->list xs) xs)))
        (filter (lambda (x) (not (na? x))) l)))

    (define (nums xs)
      (let ((l (values-of xs)))
        (for-each (lambda (x) (unless (real? x) (error "not a number" x))) l)
        l))

    (define (sum xs)
      "Syntax: (sum xs)
Library: (scm data stats)
Description: The sum of the numbers in the list or vector xs (na skipped).
Example:
  (sum (list 1 2 na 3)) => 6"
      (fold + 0 (nums xs)))

    (define (mean xs)
      "Syntax: (mean xs)
Library: (scm data stats)
Description: The arithmetic mean (inexact); na if there are no values.
Example:
  (mean #(1 2 3 4)) => 2.5"
      (let ((l (nums xs)))
        (if (null? l) na (inexact (/ (fold + 0 l) (length l))))))

    (define (weighted-mean xs ws)
      "Syntax: (weighted-mean xs weights)
Library: (scm data stats)
Description: The mean of xs weighted by ws (pairs with a na are skipped).
Example:
  (weighted-mean '(1 3) '(3 1)) => 1.5"
      (let loop ((xs (if (vector? xs) (vector->list xs) xs))
                 (ws (if (vector? ws) (vector->list ws) ws))
                 (s 0) (w 0))
        (cond ((or (null? xs) (null? ws)) (if (zero? w) na (inexact (/ s w))))
              ((or (na? (car xs)) (na? (car ws))) (loop (cdr xs) (cdr ws) s w))
              (else (loop (cdr xs) (cdr ws) (+ s (* (car xs) (car ws))) (+ w (car ws)))))))

    (define (quantile xs p)
      "Syntax: (quantile xs p)
Library: (scm data stats)
Description: The p-quantile (0 <= p <= 1) with linear interpolation (R's
  type 7, also pandas' default); p may be a list, giving a list.
Example:
  (quantile '(1 2 3 4) 0.25) => 1.75"
      (let ((v (list->vector (list-sort < (nums xs)))))
        (define (q p)
          (let ((n (vector-length v)))
            (if (= n 0)
                na
                (let* ((h (* (- n 1) p))
                       (lo (exact (floor h)))
                       (hi (min (- n 1) (+ lo 1)))
                       (a (vector-ref v lo)))
                  (+ a (* (- h lo) (- (vector-ref v hi) a)))))))
        (if (list? p) (map q p) (q p))))

    (define (median xs)
      "Syntax: (median xs)
Library: (scm data stats)
Description: The median (middle value, or mean of the two middle values).
Example:
  (median '(3 1 2 10)) => 5/2"
      (quantile xs 1/2))

    (define (var xs)
      "Syntax: (var xs)
Library: (scm data stats)
Description: The sample variance (divided by n-1); na for fewer than 2
  values.
Example:
  (var '(1 2 3 4)) => 1.6666666666666667"
      (let* ((l (nums xs)) (n (length l)))
        (if (< n 2)
            na
            (let ((m (/ (fold + 0 l) n)))
              (inexact (/ (fold (lambda (x s) (+ s (* (- x m) (- x m)))) 0 l) (- n 1)))))))

    (define (sd xs)
      "Syntax: (sd xs)
Library: (scm data stats)
Description: The sample standard deviation, (sqrt (var xs)).
Example:
  (sd '(2 4 4 4 5 5 7 9)) => 2.138089935299395"
      (let ((v (var xs))) (if (na? v) na (sqrt v))))

    (define (iqr xs)
      "Syntax: (iqr xs)
Library: (scm data stats)
Description: The interquartile range, quantile 0.75 minus quantile 0.25.
Example:
  (iqr '(1 2 3 4 5)) => 2"
      (let ((l (nums xs)))
        (if (null? l) na (- (quantile l 3/4) (quantile l 1/4)))))

    (define (value-range xs)
      "Syntax: (value-range xs)
Library: (scm data stats)
Description: The list (min max) of the numbers, #f if there are none.
Example:
  (value-range (list 3 na 1 7)) => (1 7)"
      (let ((l (nums xs)))
        (and (pair? l) (list (apply min l) (apply max l)))))

    (define (cumsum xs)
      "Syntax: (cumsum xs)
Library: (scm data stats)
Description: The running sums, as a list; na stays na and is skipped.
Example:
  (cumsum (list 1 2 na 3)) => (1 3 na 6)"
      (let loop ((l (if (vector? xs) (vector->list xs) xs)) (s 0) (acc '()))
        (cond ((null? l) (reverse acc))
              ((na? (car l)) (loop (cdr l) s (cons na acc)))
              (else (let ((s (+ s (car l)))) (loop (cdr l) s (cons s acc)))))))

    (define (ranks xs . ties)
      "Syntax: (ranks xs [ties])
Library: (scm data stats)
Description: The rank of each value (1 = smallest) as a list; ties is
  average (default, as R's rank), min or dense. na stays na.
Example:
  (ranks '(10 20 10 30)) => (1.5 3 1.5 4)"
      (let* ((method (if (pair? ties) (car ties) 'average))
             (v (if (vector? xs) xs (list->vector xs)))
             (n (vector-length v))
             (idx (list-sort (lambda (i j) (< (vector-ref v i) (vector-ref v j)))
                             (filter (lambda (i) (not (na? (vector-ref v i)))) (iota n))))
             (out (make-vector n na)))
        (let loop ((is idx) (pos 1) (dense 1))
          (unless (null? is)
            ;; the run of equal values starting at is
            (let* ((x (vector-ref v (car is)))
                   (run (let take ((r is) (acc '()))
                          (if (and (pair? r) (= (vector-ref v (car r)) x))
                              (take (cdr r) (cons (car r) acc))
                              (reverse acc))))
                   (k (length run))
                   (r (case method
                        ((min) pos)
                        ((dense) dense)
                        (else (let ((a (/ (+ pos (+ pos k -1)) 2))) (if (integer? a) a (inexact a)))))))
              (for-each (lambda (i) (vector-set! out i r)) run)
              (loop (list-tail is k) (+ pos k) (+ dense 1)))))
        (vector->list out)))

    (define (zscore xs)
      "Syntax: (zscore xs)
Library: (scm data stats)
Description: The standardised values (x - mean) / sd, as a list.
Example:
  (zscore '(1 2 3)) => (-1.0 0.0 1.0)"
      (let ((m (mean xs)) (s (sd xs)))
        (map (lambda (x) (if (or (na? x) (na? s) (zero? s)) na (/ (- x m) s)))
             (if (vector? xs) (vector->list xs) xs))))

    ;; pairs without na
    (define (pairs xs ys)
      (let loop ((xs (if (vector? xs) (vector->list xs) xs))
                 (ys (if (vector? ys) (vector->list ys) ys))
                 (acc '()))
        (if (or (null? xs) (null? ys))
            (reverse acc)
            (loop (cdr xs) (cdr ys)
                  (if (or (na? (car xs)) (na? (car ys))) acc (cons (cons (car xs) (car ys)) acc))))))

    (define (cov xs ys)
      "Syntax: (cov xs ys)
Library: (scm data stats)
Description: The sample covariance of two equally long lists (pairs with
  a na are skipped).
Example:
  (cov '(1 2 3) '(2 4 6)) => 2.0"
      (let* ((ps (pairs xs ys)) (n (length ps)))
        (if (< n 2)
            na
            (let ((mx (/ (fold + 0 (map car ps)) n))
                  (my (/ (fold + 0 (map cdr ps)) n)))
              (inexact (/ (fold (lambda (p s) (+ s (* (- (car p) mx) (- (cdr p) my)))) 0 ps)
                          (- n 1)))))))

    (define (cor xs ys . method)
      "Syntax: (cor xs ys [method])
Library: (scm data stats)
Description: The correlation coefficient; method pearson (default) or
  spearman (Pearson on the average ranks).
Example:
  (cor '(1 2 3 4) '(1 3 2 4)) => 0.8"
      (let* ((ps (pairs xs ys))
             (x (map car ps)) (y (map cdr ps)))
        (if (and (pair? method) (eq? (car method) 'spearman))
            (cor (ranks x) (ranks y))
            (let ((c (cov x y)) (sx (sd x)) (sy (sd y)))
              (if (or (na? c) (zero? sx) (zero? sy)) na (/ c (* sx sy)))))))

    (define (pct-change from to)
      "Syntax: (pct-change from to)
Library: (scm data stats)
Description: The relative change (to - from) / from as a fraction; na if
  from is 0 or a value is na.
Example:
  (pct-change 200 250) => 0.25"
      (if (or (na? from) (na? to) (zero? from)) na (inexact (- (/ to from) 1))))

    (define (freq xs . opts)
      "Syntax: (freq xs [sort])
Library: (scm data stats)
Description: A frequency table as a data frame with columns value, n and
  share (fraction); sorted by value, or by descending n with 'by-count.
  na values are counted as their own value.
Example:
  (freq '(a b a)) ; value a b, n 2 1, share 0.667 0.333"
      (let* ((l (if (vector? xs) (vector->list xs) xs))
             (h (make-hash-table equal?))
             (order '()))
        (for-each (lambda (x)
                    (unless (hash-table-exists? h x) (set! order (cons x order)))
                    (hash-table-update!/default h x (lambda (n) (+ n 1)) 0))
                  l)
        (let* ((keys (reverse order))
               (keys (if (and (pair? opts) (eq? (car opts) 'by-count))
                         (list-stable-sort (lambda (a b) (> (hash-table-ref h a) (hash-table-ref h b))) keys)
                         (list-sort generic<? keys)))
               (total (length l)))
          (make-df (list (cons 'value keys)
                         (cons 'n (map (lambda (k) (hash-table-ref h k)) keys))
                         (cons 'share (map (lambda (k) (inexact (/ (hash-table-ref h k) total))) keys)))))))

    (define (generic<? a b)
      (cond ((and (real? a) (real? b)) (< a b))
            ((and (string? a) (string? b)) (string<? a b))
            ((and (symbol? a) (symbol? b)) (string<? (symbol->string a) (symbol->string b)))
            ((na? a) #f)
            ((na? b) #t)
            ((real? a) #t)
            ((real? b) #f)
            (else (string<? (to-name a) (to-name b)))))

    (define (to-name x)
      (cond ((symbol? x) (symbol->string x))
            ((string? x) x)
            ((number? x) (number->string x))
            ((na? x) "NA")
            ((boolean? x) (if x "TRUE" "FALSE"))
            ((day? x) (day->string x))
            (else "?")))

    (define (crosstab rows cols . opts)
      "Syntax: (crosstab row-values col-values [margins?])
Library: (scm data stats)
Description: A two-way frequency table as a data frame: a column row with
  the distinct row values, then one column per distinct column value
  (named after it) holding counts. With margins? #t a total column and
  a total row are added.
Example:
  (crosstab '(a a b) '(x y x) #t)"
      (let* ((rl (if (vector? rows) (vector->list rows) rows))
             (cl (if (vector? cols) (vector->list cols) cols))
             (rk (list-sort generic<? (delete-duplicates rl)))
             (ck (list-sort generic<? (delete-duplicates cl)))
             (h (make-hash-table equal?))
             (margins? (and (pair? opts) (car opts))))
        (for-each (lambda (r c) (hash-table-update!/default h (cons r c) (lambda (n) (+ n 1)) 0)) rl cl)
        (let* ((cell (lambda (r c) (hash-table-ref/default h (cons r c) 0)))
               (cols (map (lambda (c) (cons (string->symbol (to-name c)) (map (lambda (r) (cell r c)) rk))) ck))
               (df (make-df (cons (cons 'row rk) cols))))
          (if (not margins?)
              df
              (let* ((tot (map (lambda (r) (fold + 0 (map (lambda (c) (cell r c)) ck))) rk))
                     (df (df-with-column df 'total tot))
                     (bottom (cons "total" (append (map (lambda (c) (fold + 0 (map (lambda (r) (cell r c)) rk))) ck)
                                                   (list (length rl))))))
                (make-df (map (lambda (name v extra)
                                (cons name (append (vector->list v) (list extra))))
                              (df-names df)
                              (map (lambda (n) (df-column df n)) (df-names df))
                              bottom)))))))

    (define (histogram-bins xs . opts)
      "Syntax: (histogram-bins xs [bins | 'width w])
Library: (scm data stats)
Description: Bins numbers for a histogram: a data frame with columns from,
  to and n (left-closed bins [from, to), the last one closed). The number
  of bins defaults to Sturges' rule; give a count, or 'width w for fixed
  width bins starting at a multiple of w.
Example:
  (histogram-bins '(1 2 2 3 7) 3)"
      (let ((l (nums xs)))
        (if (null? l)
            (make-df '((from) (to) (n)))
            (let* ((lo (apply min l)) (hi (apply max l))
                   (width? (and (pair? opts) (eq? (car opts) 'width)))
                   (k (cond (width? #f)
                            ((pair? opts) (car opts))
                            (else (+ 1 (exact (ceiling (/ (log (length l)) (log 2))))))))
                   (w (cond (width? (cadr opts))
                            ((= hi lo) 1)
                            (else (/ (- hi lo) k))))
                   (start (if width? (* w (exact (floor (/ lo w)))) lo))
                   (k (if width? (max 1 (exact (ceiling (/ (- hi start) w)))) k))
                   (k (if (and width? (= (+ start (* k w)) hi)) (+ k 1) k))
                   (counts (make-vector k 0)))
              (for-each (lambda (x)
                          (let ((b (min (- k 1) (exact (floor (/ (- x start) w))))))
                            (vector-set! counts b (+ 1 (vector-ref counts b)))))
                        l)
              (make-df (list (cons 'from (map (lambda (i) (+ start (* i w))) (iota k)))
                             (cons 'to (map (lambda (i) (+ start (* (+ i 1) w))) (iota k)))
                             (cons 'n (vector->list counts))))))))

    (define (lm-simple xs ys)
      "Syntax: (lm-simple xs ys)
Library: (scm data stats)
Description: Least-squares line y = intercept + slope * x; returns an
  alist ((intercept . a) (slope . b) (r2 . r²) (n . pairs)).
Example:
  (lm-simple '(1 2 3) '(2 4 6)) => ((intercept . 0.0) (slope . 2.0) (r2 . 1.0) (n . 3))"
      (let* ((ps (pairs xs ys)) (n (length ps)))
        (if (< n 2)
            (list (cons 'intercept na) (cons 'slope na) (cons 'r2 na) (cons 'n n))
            (let* ((x (map car ps)) (y (map cdr ps))
                   (mx (/ (fold + 0 x) n)) (my (/ (fold + 0 y) n))
                   (sxy (fold + 0 (map (lambda (a b) (* (- a mx) (- b my))) x y)))
                   (sxx (fold + 0 (map (lambda (a) (* (- a mx) (- a mx))) x)))
                   (syy (fold + 0 (map (lambda (b) (* (- b my) (- b my))) y)))
                   (slope (if (zero? sxx) na (/ sxy sxx))))
              (list (cons 'intercept (if (na? slope) na (inexact (- my (* slope mx)))))
                    (cons 'slope (if (na? slope) na (inexact slope)))
                    (cons 'r2 (if (or (zero? sxx) (zero? syy)) na (inexact (/ (* sxy sxy) (* sxx syy)))))
                    (cons 'n n))))))))
