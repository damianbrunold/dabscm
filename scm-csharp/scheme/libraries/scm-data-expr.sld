(define-library (scm data expr)
  (import (scheme base)
          (scheme char)
          (scheme inexact)
          (srfi 1)
          (except (srfi 13) string-hash)
          (srfi 69)
          (srfi 132)
          (scm string)
          (scm data core)
          (scm data format)
          (scm data frame)
          (prefix (scm data stats) stats:))
  (export compile-expr
          expr-uses-aggregate?
          define-df-function
          df-function-names
          value<?
          value=?
          all-rows)
  (begin

    ;; ================================================================
    ;; (scm data expr) — column expressions, as written inside the verbs
    ;; of (scm data verbs): (where df (> pts ,limit)).
    ;;
    ;; An expression is a datum: a bare symbol names a column, numbers,
    ;; strings, booleans and quoted data are constants, (f arg …) calls a
    ;; function of the vocabulary below, and a procedure in head position
    ;; (spliced in with unquote) is called per row. compile-expr turns an
    ;; expression into a procedure (lambda (i rows) …) evaluated for row i;
    ;; rows is the vector of row indices of i's group (all rows when
    ;; ungrouped), over which aggregates and window functions work.
    ;;
    ;; Missing values: scalar functions return na when an argument is na;
    ;; aggregates skip na; and/or/not/if/case-when/is-na/coalesce/in
    ;; handle na themselves (a na condition counts as false).
    ;;
    ;; Vocabulary:
    ;;   + - * / (always inexact; x/0 is na) quotient modulo abs
    ;;   (round x [digits]) floor ceiling sqrt
    ;;   (log x [base]) exp pmin pmax
    ;;   = != < <= > >= (work on numbers, strings, symbols, dates)
    ;;   and or not (if c a b) (case-when (c v) … (else v)) (in x ,list)
    ;;   (list a b …)
    ;;   (between x lo hi) is-na (coalesce a b …)
    ;;   str str-len (str-sub s start [end]) str-upper str-lower str-trim
    ;;   (str-detect s regex) (str-replace s regex repl) str-starts
    ;;   str-ends (str-pad s width [char]) ->string ->number ->int ->symbol
    ;;   parse-date year month day weekday (days-between a b)
    ;;   (date-add-days d n)
    ;;   aggregates: (n) sum mean median min max sd var (quantile x p)
    ;;     n-distinct first last any all
    ;;   window: (lag x [k]) (lead x [k]) cumsum (row-number) rank
    ;;     dense-rank share pct-change
    ;; Add functions with define-df-function.
    ;; ================================================================

    ;; --- generic comparison --------------------------------------------

    (define (type-rank x)
      (cond ((na? x) 9) ((real? x) 0) ((string? x) 1) ((symbol? x) 2)
            ((day? x) 3) ((boolean? x) 4) (else 5)))

    (define (value<? a b)
      "Syntax: (value<? a b)
Library: (scm data expr)
Description: Total order used for sorting and grouping: numbers, strings,
  symbols and dates in their natural order, #f before #t; values of
  different types by type; na sorts last.
Example:
  (value<? \"a\" \"b\") => #t"
      (let ((ra (type-rank a)) (rb (type-rank b)))
        (if (not (= ra rb))
            (< ra rb)
            (case ra
              ((0) (< a b))
              ((1) (string<? a b))
              ((2) (string<? (symbol->string a) (symbol->string b)))
              ((3) (< (day-number a) (day-number b)))
              ((4) (and (not a) b))
              ((9) #f)
              (else (string<? (fmt-value a) (fmt-value b)))))))

    (define (value=? a b)
      (cond ((and (real? a) (real? b)) (= a b))
            ((and (day? a) (day? b)) (= (day-number a) (day-number b)))
            (else (equal? a b))))

    ;; --- function registry ---------------------------------------------
    ;; kind: scalar (na in -> na out), raw (gets na as is),
    ;; agg (list of non-na values [extra args] -> value),
    ;; window (vector of the group's values [extra args] -> vector)

    (define registry (make-hash-table eq?))

    (define (define-df-function name kind proc)
      "Syntax: (define-df-function name kind proc)
Library: (scm data expr)
Description: Adds a function to the expression vocabulary. kind is
  scalar (called per row, returns na if an argument is na), raw (per row,
  gets na unchanged), agg (called with the list of the group's non-na
  values of the first argument plus the other arguments, returns one
  value) or window (called with the vector of the group's values plus the
  other arguments, returns a vector of the same length).
Example:
  (define-df-function 'sq 'scalar (lambda (x) (* x x)))
  (mutate df (pts2 (sq pts)))"
      (unless (memq kind '(scalar raw agg window))
        (error "define-df-function: unknown kind" kind))
      (hash-table-set! registry name (cons kind proc)))

    (define (df-function-names) (list-sort value<? (hash-table-keys registry)))

    (define (num-list xs) (filter real? xs))

    (define (sum-list xs) (fold + 0 xs))

    (define (round-digits x . d)
      (let* ((digits (if (pair? d) (car d) 0))
             (scale (expt 10 digits))
             (e (exact x))
             (r (/ (* (if (< e 0) -1 1) (floor (+ (* (abs e) scale) 1/2))) scale)))
        (if (and (exact? x) (= digits 0)) r (if (exact? x) r (inexact r)))))

    (define (cmp-op op)
      (lambda (a b)
        (cond ((and (real? a) (real? b)) (op a b))
              ((and (string? a) (string? b))
               (op (string-compare3 a b) 0))
              ((and (symbol? a) (symbol? b))
               (op (string-compare3 (symbol->string a) (symbol->string b)) 0))
              ((and (day? a) (day? b)) (op (day-number a) (day-number b)))
              (else (error "cannot compare" a b)))))

    (define (string-compare3 a b)
      (cond ((string<? a b) -1) ((string=? a b) 0) (else 1)))

    (define (->string* x) (fmt-value x))

    ;; ranks of the non-na values: ties get the lowest rank of the tie
    ;; (dplyr min_rank) or consecutive ranks without gaps (dense)
    (define (rank-vector v dense?)
      (let* ((n (vector-length v))
             (idx (list-sort (lambda (i j) (value<? (vector-ref v i) (vector-ref v j)))
                             (filter (lambda (i) (not (na? (vector-ref v i)))) (iota n))))
             (out (make-vector n na)))
        (let loop ((is idx) (pos 1) (dense 0) (rank 0) (prev #f))
          (unless (null? is)
            (let* ((i (car is))
                   (x (vector-ref v i))
                   (tie (and (> pos 1) (value=? x prev)))
                   (rank (if tie rank pos))
                   (dense (if tie dense (+ dense 1))))
              (vector-set! out i (if dense? dense rank))
              (loop (cdr is) (+ pos 1) dense rank x))))
        out))

    (define (init-registry!)
      (for-each (lambda (e) (define-df-function (car e) 'scalar (cdr e)))
                `((+ . ,+) (- . ,-) (* . ,*)
                  (/ . ,(lambda (a b) (if (zero? b) na (inexact (/ a b)))))
                  (quotient . ,quotient) (modulo . ,modulo) (abs . ,abs)
                  (round . ,round-digits) (floor . ,floor) (ceiling . ,ceiling)
                  (sqrt . ,sqrt) (exp . ,exp)
                  (log . ,(lambda (x . b) (if (pair? b) (/ (log x) (log (car b))) (log x))))
                  (pmin . ,min) (pmax . ,max)
                  (< . ,(cmp-op <)) (<= . ,(cmp-op <=)) (> . ,(cmp-op >)) (>= . ,(cmp-op >=))
                  (= . ,value=?) (!= . ,(lambda (a b) (not (value=? a b))))
                  (between . ,(lambda (x lo hi) (and ((cmp-op >=) x lo) ((cmp-op <=) x hi))))
                  (str-len . ,(lambda (s) (string-length (->string* s))))
                  (str-sub . ,(lambda (s start . end)
                                (let* ((s (->string* s)) (n (string-length s))
                                       (a (max 0 (min n start)))
                                       (b (if (pair? end) (max a (min n (car end))) n)))
                                  (substring s a b))))
                  (str-upper . ,(lambda (s) (string-upcase (->string* s))))
                  (str-lower . ,(lambda (s) (string-downcase (->string* s))))
                  (str-trim . ,(lambda (s) (string-trim-both (->string* s))))
                  (str-detect . ,(lambda (s re) (and (string-matches (->string* s) (string-append ".*(?:" re ").*")) #t)))
                  (str-replace . ,(lambda (s re repl) (string-replace-all-regex (->string* s) re repl)))
                  (str-starts . ,(lambda (s p) (string-prefix? p (->string* s))))
                  (str-ends . ,(lambda (s p) (string-suffix? p (->string* s))))
                  (str-pad . ,(lambda (s w . c) (let ((s (->string* s)))
                                                  (if (>= (string-length s) w) s
                                                      (string-pad s w (if (pair? c) (car c) #\space))))))
                  (->string . ,->string*)
                  (->number . ,(lambda (x) (cond ((real? x) x)
                                                 ((string? x) (or (string->number (string-trim-both x)) na))
                                                 (else na))))
                  (->int . ,(lambda (x) (let ((n (if (string? x) (string->number (string-trim-both x)) x)))
                                          (if (real? n) (exact (round-digits n)) na))))
                  (->symbol . ,(lambda (x) (if (symbol? x) x (string->symbol (->string* x)))))
                  (parse-date . ,(lambda (s) (if (day? s) s (or (string->day (->string* s)) na))))
                  (year . ,day-year) (month . ,day-month)
                  (day . ,(lambda (d) (caddr (day->ymd d))))
                  (weekday . ,day-weekday)
                  (days-between . ,(lambda (a b) (- (day-number b) (day-number a))))
                  (date-add-days . ,(lambda (d k) (day-from-number (+ (day-number d) k))))))
      ;; raw: see na
      (for-each (lambda (e) (define-df-function (car e) 'raw (cdr e)))
                `((is-na . ,na?)
                  (list . ,list)
                  (str . ,(lambda xs (apply string-append (map ->string* xs))))
                  (coalesce . ,(lambda xs (let loop ((xs xs)) (cond ((null? xs) na)
                                                                    ((na? (car xs)) (loop (cdr xs)))
                                                                    (else (car xs))))))))
      (for-each (lambda (e) (define-df-function (car e) 'agg (cdr e)))
                `((sum . ,(lambda (xs) (sum-list (num-list xs))))
                  (mean . ,(lambda (xs) (stats:mean (num-list xs))))
                  (median . ,(lambda (xs) (stats:median (num-list xs))))
                  (quantile . ,(lambda (xs p) (stats:quantile (num-list xs) p)))
                  (min . ,(lambda (xs) (if (null? xs) na (fold (lambda (x m) (if (value<? x m) x m)) (car xs) (cdr xs)))))
                  (max . ,(lambda (xs) (if (null? xs) na (fold (lambda (x m) (if (value<? m x) x m)) (car xs) (cdr xs)))))
                  (var . ,(lambda (xs) (stats:var (num-list xs))))
                  (sd . ,(lambda (xs) (stats:sd (num-list xs))))
                  (n-distinct . ,(lambda (xs) (let ((h (make-hash-table equal?)))
                                                (for-each (lambda (x) (hash-table-set! h x #t)) xs)
                                                (hash-table-size h))))
                  (first . ,(lambda (xs) (if (null? xs) na (car xs))))
                  (last . ,(lambda (xs) (if (null? xs) na (last xs))))
                  (any . ,(lambda (xs) (and (any (lambda (x) (eq? x #t)) xs) #t)))
                  (all . ,(lambda (xs) (every (lambda (x) (eq? x #t)) xs)))))
      (for-each (lambda (e) (define-df-function (car e) 'window (cdr e)))
                `((lag . ,(lambda (v . k) (let ((k (if (pair? k) (car k) 1)) (n (vector-length v)))
                                            (vector-map (lambda (i) (if (>= (- i k) 0) (vector-ref v (- i k)) na))
                                                        (list->vector (iota n))))))
                  (lead . ,(lambda (v . k) (let ((k (if (pair? k) (car k) 1)) (n (vector-length v)))
                                             (vector-map (lambda (i) (if (< (+ i k) n) (vector-ref v (+ i k)) na))
                                                         (list->vector (iota n))))))
                  (cumsum . ,(lambda (v) (let ((acc 0))
                                           (vector-map (lambda (x) (if (na? x) na (begin (set! acc (+ acc x)) acc))) v))))
                  (rank . ,(lambda (v) (rank-vector v #f)))
                  (dense-rank . ,(lambda (v) (rank-vector v #t)))
                  (share . ,(lambda (v) (let ((s (sum-list (num-list (vector->list v)))))
                                          (vector-map (lambda (x) (if (or (na? x) (zero? s)) na (inexact (/ x s)))) v))))
                  (pct-change . ,(lambda (v) (let ((n (vector-length v)))
                                               (vector-map (lambda (i)
                                                             (let ((a (if (> i 0) (vector-ref v (- i 1)) na))
                                                                   (b (vector-ref v i)))
                                                               (if (or (na? a) (na? b) (zero? a)) na (- (/ b a) 1))))
                                                           (list->vector (iota n)))))))))

    ;; --- compiler -----------------------------------------------------

    (define (all-rows df)
      (list->vector (iota (df-nrow df))))

    (define (did-you-mean name names)
      (let* ((s (symbol->string name))
             (cands (filter (lambda (n) (let ((t (symbol->string n)))
                                          (or (string-contains t s) (string-contains s t)
                                              (string-prefix-ci? (substring s 0 (min 2 (string-length s))) t))))
                            names)))
        (if (null? cands) ""
            (string-append "; did you mean " (string-join (map symbol->string cands) ", ") "?"))))

    (define (unknown-column df name)
      (error (string-append "unknown column `" (symbol->string name) "`"
                            (did-you-mean name (df-names df))
                            " (columns: " (string-join (map symbol->string (df-names df)) ", ") ")")))

    (define (truthy x) (eq? x #t))

    ;; per-group cache: recompute only when the rows vector changes
    (define (cached proc)
      (let ((key #f) (val #f))
        (lambda (rows)
          (unless (eq? rows key)
            (set! val (proc rows))
            (set! key rows))
          val)))

    ;; position of row i in the sorted rows vector
    (define (position rows i)
      (let loop ((lo 0) (hi (- (vector-length rows) 1)))
        (if (> lo hi)
            (error "row not in group" i)
            (let* ((mid (quotient (+ lo hi) 2)) (r (vector-ref rows mid)))
              (cond ((= r i) mid) ((< r i) (loop (+ mid 1) hi)) (else (loop lo (- mid 1))))))))

    (define (compile-expr df e)
      "Syntax: (compile-expr df expr)
Library: (scm data expr)
Description: Compiles a column expression against the columns of df into
  a procedure (lambda (i rows) value): the value for row i, with rows the
  vector of row indices of its group (used by aggregates and window
  functions; (all-rows df) when ungrouped). See the library comment for
  the vocabulary.
Example:
  ((compile-expr df '(* pts 2)) 0 (all-rows df))"
      (let comp ((e e))
        (cond
         ((symbol? e)
          (cond ((df-has-column? df e)
                 (let ((v (df-column df e))) (lambda (i rows) (vector-ref v i))))
                ((eq? e 'na) (lambda (i rows) na))
                (else (unknown-column df e))))
         ((procedure? e) (lambda (i rows) e))
         ((not (pair? e)) (lambda (i rows) e))
         ((eq? (car e) 'quote) (let ((v (cadr e))) (lambda (i rows) v)))
         ((procedure? (car e))
          (let ((f (car e)) (args (map comp (cdr e))))
            (lambda (i rows) (apply f (map (lambda (a) (a i rows)) args)))))
         ((not (symbol? (car e))) (error "bad expression" e))
         (else
          (case (car e)
            ((and) (let ((args (map comp (cdr e))))
                     (lambda (i rows) (every (lambda (a) (truthy (a i rows))) args))))
            ((or) (let ((args (map comp (cdr e))))
                    (lambda (i rows) (and (any (lambda (a) (truthy (a i rows))) args) #t))))
            ((not) (let ((a (comp (cadr e))))
                     (lambda (i rows) (let ((x (a i rows))) (if (na? x) na (not x))))))
            ((if) (let ((c (comp (cadr e))) (a (comp (caddr e)))
                        (b (if (pair? (cdddr e)) (comp (cadddr e)) (lambda (i rows) na))))
                    (lambda (i rows) (if (truthy (c i rows)) (a i rows) (b i rows)))))
            ((case-when)
             (let ((clauses (map (lambda (cl)
                                   (cons (if (eq? (car cl) 'else) (lambda (i rows) #t) (comp (car cl)))
                                         (comp (cadr cl))))
                                 (cdr e))))
               (lambda (i rows)
                 (let loop ((cs clauses))
                   (cond ((null? cs) na)
                         ((truthy ((caar cs) i rows)) ((cdar cs) i rows))
                         (else (loop (cdr cs))))))))
            ;; a spliced list (in x ,lst) is a constant, not a call
            ((in) (let ((x (comp (cadr e)))
                        (set (let ((s (caddr e)))
                               (if (and (pair? s) (not (procedure? (car s)))
                                        (not (and (symbol? (car s))
                                                  (or (memq (car s) '(quote if case-when))
                                                      (hash-table-ref/default registry (car s) #f)))))
                                   (lambda (i rows) s)
                                   (comp s)))))
                    (lambda (i rows)
                      (let ((v (x i rows)) (s (set i rows)))
                        (and (not (na? v))
                             (any (lambda (y) (value=? v y)) (if (vector? s) (vector->list s) s))
                             #t)))))
            ((n) (lambda (i rows) (vector-length rows)))
            ((row-number) (lambda (i rows) (+ 1 (position rows i))))
            (else
             (let ((entry (hash-table-ref/default registry (car e) #f)))
               (unless entry
                 (error (string-append "unknown function `" (symbol->string (car e))
                                       "` in expression; use ,proc to call a Scheme procedure")))
               (let ((kind (car entry)) (f (cdr entry)))
                 (case kind
                   ((scalar)
                    (let ((args (map comp (cdr e))))
                      (case (length args)
                        ((1) (let ((a (car args)))
                               (lambda (i rows) (let ((x (a i rows))) (if (na? x) na (f x))))))
                        ((2) (let ((a (car args)) (b (cadr args)))
                               (lambda (i rows) (let ((x (a i rows)) (y (b i rows)))
                                                  (if (or (na? x) (na? y)) na (f x y))))))
                        (else (lambda (i rows)
                                (let ((xs (map (lambda (a) (a i rows)) args)))
                                  (if (any na? xs) na (apply f xs))))))))
                   ((raw)
                    (let ((args (map comp (cdr e))))
                      (lambda (i rows) (apply f (map (lambda (a) (a i rows)) args)))))
                   ((agg)
                    (let* ((x (comp (cadr e)))
                           (extra (map comp (cddr e)))
                           (c (cached (lambda (rows)
                                        (let ((vals (remove na? (map (lambda (r) (x r rows)) (vector->list rows)))))
                                          (apply f vals (map (lambda (a) (a (if (> (vector-length rows) 0) (vector-ref rows 0) 0) rows))
                                                             extra)))))))
                      (lambda (i rows) (c rows))))
                   ((window)
                    (let* ((x (comp (cadr e)))
                           (extra (map comp (cddr e)))
                           (c (cached (lambda (rows)
                                        (apply f (vector-map (lambda (r) (x r rows)) rows)
                                               (map (lambda (a) (a (if (> (vector-length rows) 0) (vector-ref rows 0) 0) rows))
                                                    extra))))))
                      (lambda (i rows) (vector-ref (c rows) (position rows i))))))))))))))

    (define (expr-uses-aggregate? e)
      "Syntax: (expr-uses-aggregate? expr)
Library: (scm data expr)
Description: True if the expression calls an aggregate function (or (n)).
Example:
  (expr-uses-aggregate? '(/ (sum pts) (n))) => #t"
      (cond ((not (pair? e)) #f)
            ((eq? (car e) 'quote) #f)
            ((and (symbol? (car e))
                  (or (eq? (car e) 'n)
                      (let ((en (hash-table-ref/default registry (car e) #f)))
                        (and en (eq? (car en) 'agg)))))
             #t)
            (else (any expr-uses-aggregate? (cdr e)))))

    (init-registry!)))
