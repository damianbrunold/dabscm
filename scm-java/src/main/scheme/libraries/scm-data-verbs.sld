(define-library (scm data verbs)
  (import (scheme base)
          (scheme case-lambda)
          (srfi 1)
          (except (srfi 13) string-hash)
          (srfi 27)
          (srfi 69)
          (srfi 132)
          (scm string)
          (scm data core)
          (scm data frame)
          (scm data expr))
  (export ->
          where mutate transmute summarise summarize select rename arrange
          distinct group-by tally add-count pull relocate
          left-join inner-join full-join semi-join anti-join
          pivot-longer pivot-wider unnest-longer separate
          drop-na replace-na fill-down fill-up
          ungroup head tail slice sample-n bind-rows bind-cols
          df-filter df-mutate df-transmute df-summarise df-select df-rename
          df-arrange df-distinct df-group-by df-ungroup df-count df-add-count
          df-pull df-relocate df-head df-tail df-slice df-sample-n
          df-join df-bind-rows df-bind-cols df-pivot-longer df-pivot-wider
          df-unnest-longer df-separate df-drop-na df-replace-na df-fill
          df-group-keys df-split df-map-rows eval-column)
  (begin

    ;; ================================================================
    ;; (scm data verbs) — dplyr/tidyr-style operations on data frames.
    ;;
    ;; Every operation is a procedure (df-filter, df-mutate, …) taking
    ;; quoted expressions, and most have a macro form that quasiquotes
    ;; its arguments, so columns are written as bare names and Scheme
    ;; values are spliced in with unquote:
    ;;
    ;;   (-> cases
    ;;       (where (>= year ,from) (in splg ,mfzo-splgs))
    ;;       (mutate (delta (- v2 v1)))
    ;;       (group-by splg)
    ;;       (summarise (n (n)) (delta (sum delta)))
    ;;       (arrange (desc delta)))
    ;;
    ;; -> threads a frame through the steps as their first argument.
    ;; The row filter is called `where` and the counting verb `tally`, so
    ;; they don't clash with filter and count of (srfi 1).
    ;; Expressions: see (scm data expr).
    ;; ================================================================

    (define-syntax ->
      (syntax-rules ()
        ((_ x) x)
        ((_ x (f a ...) rest ...) (-> (f x a ...) rest ...))
        ((_ x f rest ...) (-> (f x) rest ...))))

    ;; --- groups -----------------------------------------------------

    (define (key-of x)
      ;; normalise numbers so 1 and 1.0 group together
      (if (and (real? x) (inexact? x) (integer? x) (< (abs x) 1e15)) (exact x) x))

    (define (keys<? a b)
      (let loop ((a a) (b b))
        (cond ((null? a) #f)
              ((value<? (car a) (car b)) #t)
              ((value<? (car b) (car a)) #f)
              (else (loop (cdr a) (cdr b))))))

    ;; -> list of (key-values . rows-vector), sorted by key (or in order of
    ;; first appearance with sorted? #f); one group of all rows if no cols
    (define (group-index df cols . sorted?)
      (if (null? cols)
          (list (cons '() (all-rows df)))
          (let ((vs (map (lambda (c) (df-column df c)) cols))
                (h (make-hash-table equal?))
                (order '()))
            (do ((i 0 (+ i 1))) ((= i (df-nrow df)))
              (let ((k (map (lambda (v) (key-of (vector-ref v i))) vs)))
                (let ((cell (hash-table-ref/default h k #f)))
                  (if cell
                      (set-cdr! cell (cons i (cdr cell)))
                      (let ((cell (list k i)))
                        (hash-table-set! h k cell)
                        (set! order (cons cell order)))))))
            (let ((groups (map (lambda (cell) (cons (car cell) (list->vector (reverse (cdr cell)))))
                               (reverse order))))
              (if (and (pair? sorted?) (not (car sorted?)))
                  groups
                  (list-sort (lambda (a b) (keys<? (car a) (car b))) groups))))))

    (define (df-group-keys df)
      "Syntax: (df-group-keys df)
Library: (scm data verbs)
Description: The groups of a grouped frame as a list of (key-values .
  row-index-vector), sorted by key.
Example:
  (map car (df-group-keys (group-by df splg))) => ((BEW8) (GYN2))"
      (group-index df (df-groups df)))

    (define (eval-column df expr)
      "Syntax: (eval-column df expr)
Library: (scm data verbs)
Description: Evaluates an expression for every row (per group when df is
  grouped) and returns the vector of results.
Example:
  (eval-column df '(* 2 pts))"
      (let ((f (compile-expr df expr))
            (out (make-vector (df-nrow df) na)))
        (for-each (lambda (g)
                    (let ((rows (cdr g)))
                      (vector-for-each (lambda (r) (vector-set! out r (f r rows))) rows)))
                  (df-group-keys df))
        out))

    ;; --- rows -------------------------------------------------------

    (define (df-filter df exprs)
      "Syntax: (df-filter df exprs)
Library: (scm data verbs)
Description: The rows for which all expressions are true (na counts as
  false); macro form: (where df expr …). Grouped frames evaluate
  aggregates per group, e.g. (where df (= pts (max pts))).
Example:
  (df-filter df '((> pts 10) (= splg 'BEW8)))"
      (if (null? exprs)
          df
          (let ((cols (map (lambda (e) (eval-column df e)) exprs)))
            (df-take df (list->vector
                         (filter (lambda (i) (every (lambda (c) (eq? (vector-ref c i) #t)) cols))
                                 (iota (df-nrow df))))))))

    (define-syntax where
      (syntax-rules ()
        ((_ df e ...) (df-filter df (list (quasiquote e) ...)))))

    (define (df-mutate df specs)
      "Syntax: (df-mutate df specs)
Library: (scm data verbs)
Description: Adds or replaces columns; specs is a list of (name . expr),
  evaluated in order, so later expressions see earlier results. Grouped
  frames evaluate aggregates and window functions per group. Macro form:
  (mutate df (name expr) …).
Example:
  (df-mutate df '((pts2 . (* 2 pts))))"
      (fold (lambda (spec df) (df-with-column df (car spec) (eval-column df (cdr spec))))
            df specs))

    (define-syntax mutate
      (syntax-rules ()
        ((_ df (name e) ...) (df-mutate df (list (cons 'name (quasiquote e)) ...)))))

    (define (df-transmute df specs)
      (let ((m (df-mutate df specs)))
        (df-select-columns m (delete-duplicates (append (df-groups df) (map car specs))))))

    (define-syntax transmute
      (syntax-rules ()
        ((_ df (name e) ...) (df-transmute df (list (cons 'name (quasiquote e)) ...)))))

    (define (df-summarise df specs)
      "Syntax: (df-summarise df specs)
Library: (scm data verbs)
Description: One row per group (one row if ungrouped): the grouping
  columns plus a column per (name . expr) spec, normally an aggregate
  such as (sum pts) or (n). Later specs may use earlier ones. The result
  is ungrouped and sorted by the grouping columns. Macro form:
  (summarise df (name expr) …).
Example:
  (df-summarise (df-group-by df '(splg)) '((total . (sum pts))))"
      (let* ((groups (df-group-keys df))
             (gcols (df-groups df))
             (keys (make-df (map (lambda (c j) (cons c (map (lambda (g) (list-ref (car g) j)) groups)))
                                 gcols (iota (length gcols))))))
        (let loop ((specs specs) (out keys) (env df))
          (if (null? specs)
              out
              (let* ((spec (car specs))
                     (f (compile-expr env (cdr spec)))
                     (vals (map (lambda (g)
                                  (let ((rows (cdr g)))
                                    (if (= (vector-length rows) 0) na (f (vector-ref rows 0) rows))))
                                groups))
                     (out (if (null? (df-names out))
                              (make-df (list (cons (car spec) vals)))
                              (df-with-column out (car spec) vals)))
                     ;; later specs can refer to this result: broadcast it
                     (env (df-with-column env (car spec)
                                          (let ((v (make-vector (df-nrow env) na)))
                                            (for-each (lambda (g x)
                                                        (vector-for-each (lambda (r) (vector-set! v r x)) (cdr g)))
                                                      groups vals)
                                            v))))
                (loop (cdr specs) out env))))))

    (define-syntax summarise
      (syntax-rules ()
        ((_ df (name e) ...) (df-summarise df (list (cons 'name (quasiquote e)) ...)))))

    (define-syntax summarize
      (syntax-rules ()
        ((_ df (name e) ...) (df-summarise df (list (cons 'name (quasiquote e)) ...)))))

    ;; --- columns ----------------------------------------------------

    (define (select-names df spec)
      (let ((names (df-names df)))
        (cond
         ((symbol? spec) (df-column df spec) (list spec))
         ((and (pair? spec) (eq? (car spec) 'starts-with))
          (filter (lambda (n) (string-prefix? (cadr spec) (symbol->string n))) names))
         ((and (pair? spec) (eq? (car spec) 'ends-with))
          (filter (lambda (n) (string-suffix? (cadr spec) (symbol->string n))) names))
         ((and (pair? spec) (eq? (car spec) 'contains))
          (filter (lambda (n) (string-contains (symbol->string n) (cadr spec))) names))
         ((and (pair? spec) (eq? (car spec) 'matches))
          (filter (lambda (n) (string-matches (symbol->string n) (cadr spec))) names))
         ((and (pair? spec) (eq? (car spec) 'everything)) names)
         ((and (pair? spec) (eq? (car spec) 'where))
          (filter (lambda (n) ((cadr spec) (df-column df n))) names))
         (else (error "select: bad column spec" spec)))))

    (define (df-select df specs)
      "Syntax: (df-select df specs)
Library: (scm data verbs)
Description: Keeps and orders columns. A spec is a column name,
  (starts-with \"x\"), (ends-with \"x\"), (contains \"x\"), (matches regex),
  (everything), (where pred) with pred on the column vector,
  (except spec …) to drop columns, or (rename new old). Grouping
  columns are always kept. Macro form: (select df spec …).
Example:
  (select df splg (starts-with \"pts\") (except pts-raw))"
      (let loop ((specs specs) (keep '()) (renames '()))
        (if (null? specs)
            (let* ((keep (if (null? keep) '() (reverse keep)))
                   (keep (append (remove (lambda (g) (memq g keep)) (df-groups df)) keep))
                   (sel (df-select-columns df (delete-duplicates keep))))
              (if (null? renames) sel (df-rename-columns sel renames)))
            (let ((spec (car specs)))
              (cond
               ((and (pair? spec) (eq? (car spec) 'except))
                (let* ((drop (append-map (lambda (s) (select-names df s)) (cdr spec)))
                       (base (if (null? keep) (reverse (df-names df)) keep)))
                  (loop (cdr specs) (remove (lambda (n) (memq n drop)) base) renames)))
               ((and (pair? spec) (eq? (car spec) 'rename))
                (df-column df (caddr spec))
                (loop (cdr specs) (cons (caddr spec) keep) (cons (cons (caddr spec) (cadr spec)) renames)))
               (else
                (loop (cdr specs)
                      (append (reverse (remove (lambda (n) (memq n keep)) (select-names df spec))) keep)
                      renames)))))))

    (define-syntax select
      (syntax-rules ()
        ((_ df spec ...) (df-select df (list (quasiquote spec) ...)))))

    (define (df-rename df pairs)
      "Syntax: (df-rename df pairs)
Library: (scm data verbs)
Description: Renames columns; pairs is a list of (new . old). Macro form:
  (rename df (new old) …).
Example:
  (rename df (points pts))"
      (df-rename-columns df (map (lambda (p) (cons (cdr p) (car p))) pairs)))

    (define-syntax rename
      (syntax-rules ()
        ((_ df (new old) ...) (df-rename df (list (cons 'new 'old) ...)))))

    (define (df-relocate df cols)
      (df-select-columns df (append cols (remove (lambda (n) (memq n cols)) (df-names df)))))

    (define-syntax relocate
      (syntax-rules ()
        ((_ df col ...) (df-relocate df '(col ...)))))

    (define (df-pull df col)
      "Syntax: (df-pull df col)
Library: (scm data verbs)
Description: The values of one column as a list. Macro form: (pull df col).
Example:
  (pull df splg) => (BEW8 GYN2)"
      (vector->list (df-column df col)))

    (define-syntax pull
      (syntax-rules ()
        ((_ df col) (df-pull df 'col))))

    ;; --- sorting, slicing ---------------------------------------------

    (define (df-arrange df keys)
      "Syntax: (df-arrange df keys)
Library: (scm data verbs)
Description: Sorts the rows (stable) by the keys: a column, an expression
  or (desc key) for descending order; na sorts last. Macro form:
  (arrange df key …).
Example:
  (arrange df splg (desc pts))"
      (let* ((specs (map (lambda (k)
                           (if (and (pair? k) (eq? (car k) 'desc))
                               (cons #t (eval-column (df-ungroup df) (cadr k)))
                               (cons #f (eval-column (df-ungroup df) k))))
                         keys))
             (less? (lambda (i j)
                      (let loop ((ss specs))
                        (if (null? ss)
                            #f
                            (let* ((desc (caar ss)) (v (cdar ss))
                                   (a (vector-ref v i)) (b (vector-ref v j)))
                              (cond ((and (na? a) (na? b)) (loop (cdr ss)))
                                    ((na? a) #f)
                                    ((na? b) #t)
                                    ((if desc (value<? b a) (value<? a b)) #t)
                                    ((if desc (value<? a b) (value<? b a)) #f)
                                    (else (loop (cdr ss))))))))))
        (df-take df (list->vector (list-stable-sort less? (iota (df-nrow df)))))))

    (define-syntax arrange
      (syntax-rules ()
        ((_ df key ...) (df-arrange df (list (quasiquote key) ...)))))

    (define (df-distinct df cols)
      "Syntax: (df-distinct df cols)
Library: (scm data verbs)
Description: The first row of each distinct combination of the given
  columns, keeping only those columns ('() = all columns). Macro form:
  (distinct df col …).
Example:
  (distinct df splg gln)"
      (let* ((cols (if (null? cols) (df-names df) cols))
             (groups (group-index df cols #f)))
        (df-select-columns (df-take df (list->vector (map (lambda (g) (vector-ref (cdr g) 0)) groups)))
                           cols)))

    (define-syntax distinct
      (syntax-rules ()
        ((_ df col ...) (df-distinct df '(col ...)))))

    (define (df-slice df start . end)
      "Syntax: (df-slice df start [end])
Library: (scm data verbs)
Description: Rows start (inclusive, 0-based) to end (exclusive, default
  the last row), like substring. Also: (slice df start [end]).
Example:
  (slice df 0 10)"
      (let* ((n (df-nrow df))
             (a (max 0 (min n start)))
             (b (if (pair? end) (max a (min n (car end))) n)))
        (df-take df (list->vector (iota (- b a) a)))))

    (define slice df-slice)

    (define (df-head df . n)
      "Syntax: (head df [n])
Library: (scm data verbs)
Description: The first n rows (default 6).
Example:
  (head df 3)"
      (df-slice df 0 (if (pair? n) (car n) 6)))

    (define (df-tail df . n)
      (let ((k (if (pair? n) (car n) 6)))
        (df-slice df (max 0 (- (df-nrow df) k)))))

    (define head df-head)
    (define tail df-tail)

    (define (df-sample-n df n . seed)
      "Syntax: (sample-n df n [seed])
Library: (scm data verbs)
Description: n rows drawn at random without replacement (in their
  original order); a seed makes the draw reproducible.
Example:
  (sample-n df 100 42)"
      (let* ((src (make-random-source))
             (_ (when (pair? seed) (random-source-pseudo-randomize! src (car seed) 0)))
             (rand (random-source-make-integers src))
             (v (list->vector (iota (df-nrow df))))
             (k (min n (df-nrow df))))
        ;; partial Fisher-Yates
        (do ((i 0 (+ i 1))) ((= i k))
          (let* ((j (+ i (rand (- (vector-length v) i))))
                 (t (vector-ref v i)))
            (vector-set! v i (vector-ref v j))
            (vector-set! v j t)))
        (df-take df (list->vector (list-sort < (vector->list (vector-copy v 0 k)))))))

    (define sample-n df-sample-n)

    ;; --- grouping ---------------------------------------------------

    (define (df-group-by df cols)
      "Syntax: (df-group-by df cols)
Library: (scm data verbs)
Description: The frame grouped by the given columns; summarise, mutate,
  where and tally then work per group. Macro form: (group-by df col …).
Example:
  (group-by df splg year)"
      (df-set-groups df cols))

    (define-syntax group-by
      (syntax-rules ()
        ((_ df col ...) (df-group-by df '(col ...)))))

    (define (df-ungroup df) (df-set-groups df '()))
    (define ungroup df-ungroup)

    (define (df-count df cols)
      "Syntax: (df-count df cols)
Library: (scm data verbs)
Description: The number of rows per combination of cols (column n),
  sorted by cols; with no cols, of the existing groups (or all rows).
  Macro form: (tally df col …).
Example:
  (tally df splg year)"
      (let ((g (if (null? cols) df (df-group-by df cols))))
        (df-summarise g '((n . (n))))))

    (define-syntax tally
      (syntax-rules ()
        ((_ df col ...) (df-count df '(col ...)))))

    (define (df-add-count df cols)
      (let ((g (df-group-by df cols)))
        (df-set-groups (df-mutate g '((n . (n)))) (df-groups df))))

    (define-syntax add-count
      (syntax-rules ()
        ((_ df col ...) (df-add-count df '(col ...)))))

    (define (df-split df)
      "Syntax: (df-split df)
Library: (scm data verbs)
Description: A grouped frame as a list of (key-values . frame), one per
  group, sorted by key.
Example:
  (df-split (group-by df splg))"
      (map (lambda (g) (cons (car g) (df-ungroup (df-take df (cdr g)))))
           (df-group-keys df)))

    (define (df-map-rows df proc)
      "Syntax: (df-map-rows df proc)
Library: (scm data verbs)
Description: Calls proc with each row as an alist and returns the list of
  results (escape hatch for anything the verbs don't cover).
Example:
  (df-map-rows df (lambda (r) (cdr (assq 'pts r))))"
      (map proc (df->alists df)))

    ;; --- combining --------------------------------------------------

    (define (suffixed name suffix) (string->symbol (string-append (symbol->string name) suffix)))

    (define (df-join kind x y by . suffixes)
      "Syntax: (df-join kind x y by [suffix-x suffix-y])
Library: (scm data verbs)
Description: Joins two frames on key columns. kind is left, inner, full,
  semi (rows of x with a match) or anti (rows of x without). by lists the
  keys: a name present in both, or (x-name . y-name); '() means all
  common column names. Non-key columns present in both get the suffixes
  (default \".x\" and \".y\"). Macro forms: (left-join x y [(by key …)]),
  inner-join, full-join, semi-join, anti-join.
Example:
  (left-join pts limits (by splg))"
      (let* ((sx (if (pair? suffixes) (car suffixes) ".x"))
             (sy (if (and (pair? suffixes) (pair? (cdr suffixes))) (cadr suffixes) ".y"))
             (by (if (null? by)
                     (filter (lambda (n) (memq n (df-names y))) (df-names x))
                     by))
             (_ (when (null? by) (error "join: no common columns; give (by …)")))
             (xk (map (lambda (b) (if (pair? b) (car b) b)) by))
             (yk (map (lambda (b) (if (pair? b) (cdr b) b)) by))
             (x (df-ungroup x)) (y (df-ungroup y))
             (xkv (map (lambda (c) (df-column x c)) xk))
             (ykv (map (lambda (c) (df-column y c)) yk))
             (key (lambda (vs i) (let ((k (map (lambda (v) (key-of (vector-ref v i))) vs)))
                                   (and (not (any na? k)) k))))
             (h (make-hash-table equal?)))
        (do ((j (- (df-nrow y) 1) (- j 1))) ((< j 0))
          (let ((k (key ykv j)))
            (when k (hash-table-update!/default h k (lambda (l) (cons j l)) '()))))
        (case kind
          ((semi anti)
           (df-take x (list->vector
                       (filter (lambda (i) (let ((m (let ((k (key xkv i))) (and k (hash-table-ref/default h k #f)))))
                                             (if (eq? kind 'semi) m (not m))))
                               (iota (df-nrow x))))))
          ((left inner full)
           (let* ((pairs '()) (used (make-vector (df-nrow y) #f)))
             (do ((i 0 (+ i 1))) ((= i (df-nrow x)))
               (let* ((k (key xkv i))
                      (m (if k (hash-table-ref/default h k '()) '())))
                 (cond ((pair? m)
                        (for-each (lambda (j) (vector-set! used j #t) (set! pairs (cons (cons i j) pairs))) m))
                       ((memq kind '(left full)) (set! pairs (cons (cons i #f) pairs))))))
             (when (eq? kind 'full)
               (do ((j 0 (+ j 1))) ((= j (df-nrow y)))
                 (unless (vector-ref used j) (set! pairs (cons (cons #f j) pairs)))))
             (let* ((pairs (reverse pairs))
                    (yrest (remove (lambda (n) (memq n yk)) (df-names y)))
                    (xnames (df-names x))
                    (clash (filter (lambda (n) (memq n xnames)) yrest))
                    (pick (lambda (v idx) (list->vector (map (lambda (p) (let ((r (idx p))) (if r (vector-ref v r) na))) pairs))))
                    (xcols (map (lambda (n)
                                  (let ((kpos (list-index (lambda (k) (eq? k n)) xk)))
                                    (cons (if (memq n clash) (suffixed n sx) n)
                                          (if kpos
                                              ;; key: from y for y-only rows
                                              (let ((xv (df-column x n)) (yv (df-column y (list-ref yk kpos))))
                                                (list->vector (map (lambda (p) (if (car p) (vector-ref xv (car p)) (vector-ref yv (cdr p)))) pairs)))
                                              (pick (df-column x n) car)))))
                                xnames))
                    (ycols (map (lambda (n) (cons (if (memq n clash) (suffixed n sy) n)
                                                  (pick (df-column y n) cdr)))
                                yrest)))
               (make-df (append xcols ycols)))))
          (else (error "join: unknown kind" kind)))))

    (define (by-spec opts)
      (let ((b (find (lambda (o) (and (pair? o) (eq? (car o) 'by))) opts)))
        (if b (cdr b) '())))

    (define-syntax left-join
      (syntax-rules () ((_ x y opt ...) (df-join 'left x y (by-spec (list (quasiquote opt) ...))))))
    (define-syntax inner-join
      (syntax-rules () ((_ x y opt ...) (df-join 'inner x y (by-spec (list (quasiquote opt) ...))))))
    (define-syntax full-join
      (syntax-rules () ((_ x y opt ...) (df-join 'full x y (by-spec (list (quasiquote opt) ...))))))
    (define-syntax semi-join
      (syntax-rules () ((_ x y opt ...) (df-join 'semi x y (by-spec (list (quasiquote opt) ...))))))
    (define-syntax anti-join
      (syntax-rules () ((_ x y opt ...) (df-join 'anti x y (by-spec (list (quasiquote opt) ...))))))

    (define (df-bind-rows dfs . id)
      "Syntax: (df-bind-rows frames [id-column labels])
Library: (scm data verbs)
Description: Stacks frames on top of each other; columns are matched by
  name (missing ones filled with na). With an id-column, a first column
  tells which frame each row came from (labels, default 1, 2, …). Also:
  (bind-rows df …).
Example:
  (df-bind-rows (list a b) 'year '(2024 2025))"
      (let* ((dfs (map df-ungroup dfs))
             (names (fold (lambda (df acc) (append acc (remove (lambda (n) (memq n acc)) (df-names df))))
                          '() dfs))
             (cols (map (lambda (n)
                          (cons n (apply vector-append
                                         (map (lambda (df) (if (df-has-column? df n)
                                                               (df-column df n)
                                                               (make-vector (df-nrow df) na)))
                                              dfs))))
                        names)))
        (if (pair? id)
            (let ((labels (if (pair? (cdr id)) (cadr id) (iota (length dfs) 1))))
              (make-df (cons (cons (car id)
                                   (apply vector-append (map (lambda (df l) (make-vector (df-nrow df) l)) dfs labels)))
                             cols)))
            (if (null? cols) empty-df (make-df cols)))))

    (define (bind-rows . dfs) (df-bind-rows dfs))

    (define (df-bind-cols dfs)
      (make-df (append-map df-columns dfs)))

    (define (bind-cols . dfs) (df-bind-cols dfs))

    ;; --- reshaping --------------------------------------------------

    (define (opt-value opts key dflt)
      (let ((o (find (lambda (o) (and (pair? o) (eq? (car o) key))) opts)))
        (if o (cdr o) dflt)))

    (define (df-pivot-longer df cols names-to values-to)
      "Syntax: (df-pivot-longer df cols names-to values-to)
Library: (scm data verbs)
Description: Turns the columns cols into rows: each row becomes one row per
  column, with the column name (a symbol) in names-to and the value in
  values-to; the other columns are repeated. Macro form:
  (pivot-longer df (cols c …) (names-to name) (values-to name)).
Example:
  (pivot-longer df (cols v1 v2) (names-to model) (values-to pts))"
      (let* ((df (df-ungroup df))
             (ids (remove (lambda (n) (memq n cols)) (df-names df)))
             (n (df-nrow df)) (k (length cols))
             (rows (list->vector (append-map (lambda (i) (make-list k i)) (iota n))))
             (base (df-select-columns (df-take df rows) ids))
             (names (list->vector (append-map (lambda (i) cols) (iota n))))
             (vals (let ((vs (map (lambda (c) (df-column df c)) cols)))
                     (list->vector (append-map (lambda (i) (map (lambda (v) (vector-ref v i)) vs)) (iota n))))))
        (df-with-columns base (list (cons names-to names) (cons values-to vals)))))

    (define-syntax pivot-longer
      (syntax-rules ()
        ((_ df opt ...)
         (let ((opts (list (quasiquote opt) ...)))
           (df-pivot-longer df (opt-value opts 'cols '())
                            (car (opt-value opts 'names-to '(name)))
                            (car (opt-value opts 'values-to '(value))))))))

    (define (df-pivot-wider df names-from values-from . fill)
      "Syntax: (df-pivot-wider df names-from values-from [fill])
Library: (scm data verbs)
Description: Turns rows into columns: one column per distinct value of the
  names-from columns (joined with _ when several), holding values-from;
  the remaining columns identify the rows. Missing combinations get fill
  (default na). Macro form:
  (pivot-wider df (names-from col …) (values-from col) [(values-fill v)]).
Example:
  (pivot-wider df (names-from year model) (values-from pts) (values-fill 0))"
      (let* ((df (df-ungroup df))
             (fillv (if (pair? fill) (car fill) na))
             (ids (remove (lambda (n) (or (memq n names-from) (eq? n values-from))) (df-names df)))
             (newname (lambda (i) (string->symbol
                                   (string-join (map (lambda (c) (fmt-name (df-ref df i c))) names-from) "_"))))
             (newnames (delete-duplicates (map newname (iota (df-nrow df)))))
             (groups (group-index df ids #f))
             (vals (df-column df values-from))
             (cols (map (lambda (nn) (cons nn (make-vector (length groups) fillv))) newnames)))
        (for-each (lambda (g gi)
                    (vector-for-each (lambda (r)
                                       (vector-set! (cdr (assq (newname r) cols)) gi (vector-ref vals r)))
                                     (cdr g)))
                  groups (iota (length groups)))
        (let ((base (df-select-columns (df-take df (list->vector (map (lambda (g) (vector-ref (cdr g) 0)) groups)))
                                       ids)))
          (if (null? ids) (make-df cols) (df-with-columns base cols)))))

    (define (fmt-name x)
      (cond ((symbol? x) (symbol->string x))
            ((string? x) x)
            ((number? x) (number->string x))
            ((na? x) "NA")
            (else (let ((p (open-output-string))) (write x p) (get-output-string p)))))

    (define-syntax pivot-wider
      (syntax-rules ()
        ((_ df opt ...)
         (let ((opts (list (quasiquote opt) ...)))
           (apply df-pivot-wider df (opt-value opts 'names-from '())
                  (car (opt-value opts 'values-from '(value)))
                  (let ((f (opt-value opts 'values-fill #f))) (if f (list (car f)) '())))))))

    (define (df-unnest-longer df col . into)
      "Syntax: (df-unnest-longer df col [into])
Library: (scm data verbs)
Description: One row per element of the list column col (rows with an
  empty list are dropped). With into, a list of names, each element must
  be a list and is spread into those columns (col is dropped). Macro form:
  (unnest-longer df col [(into name …)]).
Example:
  (unnest-longer cases operateure (into gln splg points))"
      (let* ((df (df-ungroup df))
             (v (df-column df col))
             (rows (list->vector (append-map (lambda (i) (let ((x (vector-ref v i)))
                                                           (if (list? x) (make-list (length x) i) (list i))))
                                             (iota (df-nrow df)))))
             (elems (list->vector (append-map (lambda (i) (let ((x (vector-ref v i))) (if (list? x) x (list x))))
                                              (iota (df-nrow df)))))
             (base (df-take df rows)))
        (if (and (pair? into) (pair? (car into)))
            (df-with-columns (df-drop-columns base (list col))
                             (map (lambda (name j)
                                    (cons name (vector-map (lambda (e) (if (and (list? e) (> (length e) j)) (list-ref e j) na))
                                                           elems)))
                                  (car into) (iota (length (car into)))))
            (df-with-column base col elems))))

    (define-syntax unnest-longer
      (syntax-rules ()
        ((_ df col) (df-unnest-longer df 'col))
        ((_ df col opt) (df-unnest-longer df 'col (opt-value (list (quasiquote opt)) 'into #f)))))

    (define (df-separate df col into sep)
      "Syntax: (df-separate df col into separator-regex)
Library: (scm data verbs)
Description: Splits a string column into several columns at a separator
  (a regular expression); missing parts become na. Macro form:
  (separate df col (into a b …) [(sep regex)]) (default separator: one
  of space , ; : / _ - .).
Example:
  (separate df falltyp (into art stat sub) (sep \":\"))"
      (let* ((v (df-column df col))
             (parts (vector-map (lambda (x) (if (na? x) '() (string-split (fmt-name x) sep))) v)))
        (df-with-columns (df-drop-columns df (list col))
                         (map (lambda (name j)
                                (cons name (vector-map (lambda (p) (if (> (length p) j) (list-ref p j) na)) parts)))
                              into (iota (length into))))))

    (define-syntax separate
      (syntax-rules ()
        ((_ df col opt ...)
         (let ((opts (list (quasiquote opt) ...)))
           (df-separate df 'col (opt-value opts 'into '())
                        (car (opt-value opts 'sep '("[ ,;:/_.-]"))))))))

    ;; --- missing values ---------------------------------------------

    (define (df-drop-na df cols)
      "Syntax: (df-drop-na df cols)
Library: (scm data verbs)
Description: The rows without na in cols ('() = in any column). Macro
  form: (drop-na df col …).
Example:
  (drop-na df pts)"
      (let ((vs (map (lambda (c) (df-column df c)) (if (null? cols) (df-names df) cols))))
        (df-take df (list->vector (filter (lambda (i) (not (any (lambda (v) (na? (vector-ref v i))) vs)))
                                          (iota (df-nrow df)))))))

    (define-syntax drop-na
      (syntax-rules () ((_ df col ...) (df-drop-na df '(col ...)))))

    (define (df-replace-na df pairs)
      "Syntax: (df-replace-na df pairs)
Library: (scm data verbs)
Description: Replaces na in the given columns; pairs is ((col . value) …).
  Macro form: (replace-na df (col value) …).
Example:
  (replace-na df (pts 0))"
      (fold (lambda (p df)
              (df-with-column df (car p) (vector-map (lambda (x) (if (na? x) (cdr p) x)) (df-column df (car p)))))
            df pairs))

    (define-syntax replace-na
      (syntax-rules ()
        ((_ df (col v) ...) (df-replace-na df (list (cons 'col (quasiquote v)) ...)))))

    (define (df-fill df cols direction)
      "Syntax: (df-fill df cols direction)
Library: (scm data verbs)
Description: Fills na with the previous (direction down) or next (up)
  non-na value of the column, per group. Macro forms: (fill-down df col …),
  (fill-up df col …).
Example:
  (fill-down df kanton)"
      (fold (lambda (c df)
              (let ((v (vector-copy (df-column df c))))
                (for-each (lambda (g)
                            (let ((rows (vector->list (cdr g))))
                              (let loop ((rs (if (eq? direction 'up) (reverse rows) rows)) (last na))
                                (unless (null? rs)
                                  (let ((x (vector-ref v (car rs))))
                                    (if (na? x)
                                        (begin (vector-set! v (car rs) last) (loop (cdr rs) last))
                                        (loop (cdr rs) x)))))))
                          (df-group-keys df))
                (df-with-column df c v)))
            df cols))

    (define-syntax fill-down
      (syntax-rules () ((_ df col ...) (df-fill df '(col ...) 'down))))
    (define-syntax fill-up
      (syntax-rules () ((_ df col ...) (df-fill df '(col ...) 'up))))))
