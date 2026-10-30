(define-library (scm data frame)
  (import (scheme base)
          (scheme case-lambda)
          (scheme write)
          (srfi 1)
          (srfi 13)
          (scm data core)
          (scm data format))
  (export data-frame?
          make-df
          rows->df
          alists->df
          tibble
          empty-df
          df-nrow
          df-ncol
          df-names
          df-has-column?
          df-column
          df-columns
          df-ref
          df-row
          df->rows
          df->alists
          df-types
          df-column-type
          df-groups
          df-set-groups
          df-with-column
          df-with-columns
          df-drop-columns
          df-select-columns
          df-rename-columns
          df-take
          df-print
          df-head-string
          df->string
          df-glimpse)
  (begin

    ;; ================================================================
    ;; (scm data frame) — a column-oriented table, like an R tibble or a
    ;; pandas DataFrame. Columns have symbol names and are vectors of
    ;; equal length; cells are numbers, strings, booleans, dates (see
    ;; (scm data core)), symbols, lists, or na for a missing value.
    ;;
    ;; Frames are immutable values: every operation returns a new frame
    ;; and shares the column vectors it doesn't change, so never mutate
    ;; a vector obtained from df-column.
    ;;
    ;; A frame can carry grouping columns (set by group-by in
    ;; (scm data verbs)); summarise and grouped mutate use them.
    ;; ================================================================

    (define-record-type <data-frame>
      (%make-df names cols nrow groups)
      data-frame?
      (names df-names)        ; list of symbols
      (cols %df-cols)         ; list of vectors, same order
      (nrow df-nrow)
      (groups df-groups))     ; list of symbols, '() = ungrouped

    (define (->symbol x)
      (cond ((symbol? x) x)
            ((string? x) (string->symbol x))
            (else (error "column name must be a symbol or string" x))))

    (define (->vector x)
      (cond ((vector? x) x)
            ((list? x) (list->vector x))
            (else (vector x))))

    (define (check-unique names)
      (let loop ((ns names))
        (unless (null? ns)
          (when (memq (car ns) (cdr ns))
            (error "duplicate column name" (car ns)))
          (loop (cdr ns)))))

    (define (build names cols groups)
      (check-unique names)
      (let ((n (if (null? cols) 0 (vector-length (car cols)))))
        (for-each (lambda (name c)
                    (unless (= (vector-length c) n)
                      (error "column has wrong length" name (vector-length c) n)))
                  names cols)
        (%make-df names cols n (filter (lambda (g) (memq g names)) groups))))

    (define empty-df (%make-df '() '() 0 '()))

    (define (make-df columns)
      "Syntax: (make-df columns)
Library: (scm data frame)
Description: A frame from an alist of (name . values), values being a
  vector or a list. A single non-list value is recycled to the length of
  the other columns.
Example:
  (df-nrow (make-df '((a . #(1 2 3)) (b . (\"x\" \"y\" \"z\"))))) => 3"
      (let* ((names (map (lambda (c) (->symbol (car c))) columns))
             (vals (map (lambda (c) (cdr c)) columns))
             (n (fold (lambda (v m) (if (or (vector? v) (list? v))
                                        (max m (if (vector? v) (vector-length v) (length v)))
                                        m))
                      0 vals))
             (cols (map (lambda (v)
                          (if (or (vector? v) (list? v)) (->vector v) (make-vector n v)))
                        vals)))
        (build names cols '())))

    (define-syntax tibble
      (syntax-rules ()
        ((_ (name value ...) ...)
         (make-df (list (cons 'name (vector value ...)) ...)))))

    (define (rows->df names rows)
      "Syntax: (rows->df names rows)
Library: (scm data frame)
Description: A frame from a list of rows; each row is a list or vector of
  cells in the order of names. Short rows are filled with na.
Example:
  (df-ref (rows->df '(a b) '((1 \"x\") (2 \"y\"))) 1 'b) => \"y\""
      (let* ((names (map ->symbol names))
             (k (length names))
             (n (length rows))
             (cols (list-tabulate k (lambda (_) (make-vector n na)))))
        (let loop ((rs rows) (i 0))
          (unless (null? rs)
            (let ((r (car rs)))
              (let fill ((j 0) (cs cols))
                (unless (null? cs)
                  (let ((len (if (vector? r) (vector-length r) (length r))))
                    (when (< j len)
                      (vector-set! (car cs) i (if (vector? r) (vector-ref r j) (list-ref r j)))))
                  (fill (+ j 1) (cdr cs)))))
            (loop (cdr rs) (+ i 1))))
        (build names cols '())))

    (define (alists->df alists . names)
      "Syntax: (alists->df alists [names])
Library: (scm data frame)
Description: A frame from a list of rows given as alists ((key . value) …),
  keys being symbols or strings. Columns are the keys in order of first
  appearance (or the given names); missing keys become na.
Example:
  (df-names (alists->df '(((a . 1)) ((a . 2) (b . 3))))) => (a b)"
      (let* ((names (if (pair? names)
                        (map ->symbol (car names))
                        (let loop ((rs alists) (acc '()))
                          (if (null? rs)
                              (reverse acc)
                              (loop (cdr rs)
                                    (fold (lambda (p acc)
                                            (let ((k (->symbol (car p))))
                                              (if (memq k acc) acc (cons k acc))))
                                          acc (car rs)))))))
             (n (length alists))
             (cols (map (lambda (_) (make-vector n na)) names)))
        (let loop ((rs alists) (i 0))
          (unless (null? rs)
            (for-each (lambda (p)
                        (let* ((k (->symbol (car p)))
                               (pos (list-index (lambda (x) (eq? x k)) names)))
                          (when pos (vector-set! (list-ref cols pos) i (cdr p)))))
                      (car rs))
            (loop (cdr rs) (+ i 1))))
        (build names cols '())))

    (define (df-ncol df) (length (df-names df)))

    (define (df-has-column? df name)
      (and (memq (->symbol name) (df-names df)) #t))

    (define (df-column df name)
      "Syntax: (df-column df name)
Library: (scm data frame)
Description: The vector of column name (do not mutate it).
Example:
  (df-column (tibble (a 1 2)) 'a) => #(1 2)"
      (let ((name (->symbol name)))
        (let loop ((ns (df-names df)) (cs (%df-cols df)))
          (cond ((null? ns)
                 (error (string-append "unknown column `" (symbol->string name)
                                       "`; columns: "
                                       (string-join (map symbol->string (df-names df)) ", "))))
                ((eq? (car ns) name) (car cs))
                (else (loop (cdr ns) (cdr cs)))))))

    (define (df-columns df)
      "Syntax: (df-columns df)
Library: (scm data frame)
Description: The columns as an alist ((name . vector) …).
Example:
  (df-columns (tibble (a 1))) => ((a . #(1)))"
      (map cons (df-names df) (%df-cols df)))

    (define (df-ref df i name)
      "Syntax: (df-ref df row name)
Library: (scm data frame)
Description: The cell in row i (0-based) of column name.
Example:
  (df-ref (tibble (a 1 2)) 1 'a) => 2"
      (vector-ref (df-column df name) i))

    (define (df-row df i)
      "Syntax: (df-row df i)
Library: (scm data frame)
Description: Row i (0-based) as an alist ((name . value) …).
Example:
  (df-row (tibble (a 1 2) (b 3 4)) 0) => ((a . 1) (b . 3))"
      (map (lambda (n c) (cons n (vector-ref c i))) (df-names df) (%df-cols df)))

    (define (df->rows df)
      "Syntax: (df->rows df)
Library: (scm data frame)
Description: The rows as a list of lists, cells in column order.
Example:
  (df->rows (tibble (a 1 2) (b 3 4))) => ((1 3) (2 4))"
      (list-tabulate (df-nrow df)
                     (lambda (i) (map (lambda (c) (vector-ref c i)) (%df-cols df)))))

    (define (df->alists df)
      "Syntax: (df->alists df)
Library: (scm data frame)
Description: The rows as a list of alists.
Example:
  (df->alists (tibble (a 1))) => (((a . 1)))"
      (list-tabulate (df-nrow df) (lambda (i) (df-row df i))))

    (define (df-column-type df name)
      (column-type (df-column df name)))

    (define (df-types df)
      "Syntax: (df-types df)
Library: (scm data frame)
Description: The column types as an alist ((name . type) …), see
  column-type in (scm data core).
Example:
  (df-types (tibble (a 1 2) (b \"x\" na))) => ((a . int) (b . string))"
      (map (lambda (n c) (cons n (column-type c))) (df-names df) (%df-cols df)))

    (define (df-set-groups df groups)
      "Syntax: (df-set-groups df names)
Library: (scm data frame)
Description: The same frame grouped by the given columns ('() ungroups).
Example:
  (df-groups (df-set-groups (tibble (a 1)) '(a))) => (a)"
      (let ((gs (map ->symbol groups)))
        (for-each (lambda (g) (df-column df g)) gs)
        (%make-df (df-names df) (%df-cols df) (df-nrow df) gs)))

    (define (df-with-column df name values)
      "Syntax: (df-with-column df name values)
Library: (scm data frame)
Description: Adds column name at the end, or replaces it in place. values
  is a vector, a list, or one value recycled to all rows.
Example:
  (df-names (df-with-column (tibble (a 1)) 'b 0)) => (a b)"
      (let* ((name (->symbol name))
             (v (cond ((vector? values) values)
                      ((list? values) (list->vector values))
                      (else (make-vector (df-nrow df) values)))))
        (if (and (null? (df-names df)))
            (build (list name) (list v) '())
            (if (memq name (df-names df))
                (build (df-names df)
                       (map (lambda (n c) (if (eq? n name) v c)) (df-names df) (%df-cols df))
                       (df-groups df))
                (build (append (df-names df) (list name))
                       (append (%df-cols df) (list v))
                       (df-groups df))))))

    (define (df-with-columns df columns)
      "Syntax: (df-with-columns df columns)
Library: (scm data frame)
Description: df-with-column for each (name . values) of an alist.
Example:
  (df-ncol (df-with-columns (tibble (a 1)) '((b . 2) (c . 3)))) => 3"
      (fold (lambda (c df) (df-with-column df (car c) (cdr c))) df columns))

    (define (df-select-columns df names)
      "Syntax: (df-select-columns df names)
Library: (scm data frame)
Description: A frame with only the given columns, in the given order.
Example:
  (df-names (df-select-columns (tibble (a 1) (b 2)) '(b))) => (b)"
      (let ((names (map ->symbol names)))
        (build names (map (lambda (n) (df-column df n)) names) (df-groups df))))

    (define (df-drop-columns df names)
      (let ((names (map ->symbol names)))
        (df-select-columns df (remove (lambda (n) (memq n names)) (df-names df)))))

    (define (df-rename-columns df renames)
      "Syntax: (df-rename-columns df renames)
Library: (scm data frame)
Description: Renames columns; renames is an alist ((old . new) …).
Example:
  (df-names (df-rename-columns (tibble (a 1)) '((a . x)))) => (x)"
      (let ((rn (map (lambda (p) (cons (->symbol (car p)) (->symbol (cdr p)))) renames)))
        (for-each (lambda (p) (df-column df (car p))) rn)
        (let ((f (lambda (n) (let ((p (assq n rn))) (if p (cdr p) n)))))
          (build (map f (df-names df)) (%df-cols df) (map f (df-groups df))))))

    (define (df-take df idx)
      "Syntax: (df-take df indices)
Library: (scm data frame)
Description: A frame with the rows at the given 0-based indices (a vector
  or list), in that order; an index may repeat.
Example:
  (df-column (df-take (tibble (a 10 20 30)) #(2 0)) 'a) => #(30 10)"
      (let ((idx (->vector idx)))
        (%make-df (df-names df)
                  (map (lambda (c) (vector-map (lambda (i) (vector-ref c i)) idx))
                       (%df-cols df))
                  (vector-length idx)
                  (df-groups df))))

    ;; --- printing ---------------------------------------------------

    (define type-abbrev
      '((int . "<int>") (real . "<dbl>") (string . "<chr>") (bool . "<lgl>")
        (date . "<date>") (symbol . "<sym>") (list . "<list>") (mixed . "<mix>")
        (na . "<na>") (other . "<obj>")))

    (define (one-line s)
      (if (or (string-index s #\newline) (string-index s #\return))
          (string-map (lambda (c) (if (memv c '(#\newline #\return)) #\space c)) s)
          s))

    (define (cell->string x max-width)
      (let ((s (one-line (fmt-value x))))
        (if (> (string-length s) max-width)
            (string-append (substring s 0 (- max-width 1)) "…")
            s)))

    (define (df-head-string df n max-width)
      (let* ((rows (min n (df-nrow df)))
             (names (df-names df))
             (types (map (lambda (c) (column-type c)) (%df-cols df)))
             (cells (map (lambda (c)
                           (list-tabulate rows (lambda (i) (cell->string (vector-ref c i) max-width))))
                         (%df-cols df)))
             (headers (map symbol->string names))
             (tstrs (map (lambda (t) (cdr (or (assq t type-abbrev) '(x . "?")))) types))
             (widths (map (lambda (h t cs)
                            (fold (lambda (s m) (max m (string-length s)))
                                  (max (string-length h) (string-length t)) cs))
                          headers tstrs cells))
             (right? (map (lambda (t) (memq t '(int real))) types))
             (pad (lambda (s w r?) (if r? (string-pad s w) (string-pad-right s w))))
             (rowno-w (string-length (number->string (max rows 1))))
             (line (lambda (prefix strs)
                     (string-append
                      (string-pad-right prefix rowno-w) " "
                      (string-join (map pad strs widths right?) "  ")
                      "\n")))
             (out (open-output-string)))
        (write-string (string-append "# A data frame: " (number->string (df-nrow df))
                                     " × " (number->string (df-ncol df))
                                     (if (null? (df-groups df))
                                         ""
                                         (string-append ", groups: "
                                                        (string-join (map symbol->string (df-groups df)) ", ")))
                                     "\n")
                      out)
        (unless (null? names)
          (write-string (line "" headers) out)
          (write-string (line "" tstrs) out)
          (do ((i 0 (+ i 1))) ((= i rows))
            (write-string (line (number->string (+ i 1))
                                (map (lambda (cs) (list-ref cs i)) cells))
                          out)))
        (when (> (df-nrow df) rows)
          (write-string (string-append "# … " (number->string (- (df-nrow df) rows))
                                       " more rows\n")
                        out))
        (get-output-string out)))

    (define (df->string df . opts)
      "Syntax: (df->string df [n])
Library: (scm data frame)
Description: The first n rows (default 10) as an aligned text table with
  the column types under the header.
Example:
  (display (df->string (tibble (a 1 2))))"
      (df-head-string df (if (pair? opts) (car opts) 10) 30))

    (define df-print
      (case-lambda
        ((df) (df-print df 10 (current-output-port)))
        ((df n) (df-print df n (current-output-port)))
        ((df n port) (write-string (df-head-string df n 30) port))))

    (define (df-glimpse df . port)
      "Syntax: (df-glimpse df [port])
Library: (scm data frame)
Description: Prints one line per column: name, type and the first values,
  like dplyr's glimpse.
Example:
  (df-glimpse (tibble (a 1 2)))"
      (let* ((port (if (pair? port) (car port) (current-output-port)))
             (w (fold (lambda (n m) (max m (string-length (symbol->string n)))) 0 (df-names df))))
        (write-string (string-append "Rows: " (number->string (df-nrow df))
                                     "\nColumns: " (number->string (df-ncol df)) "\n")
                      port)
        (for-each
         (lambda (n c)
           (let* ((t (cdr (or (assq (column-type c) type-abbrev) '(x . "?"))))
                  (vals (string-join
                         (list-tabulate (min 8 (vector-length c))
                                        (lambda (i) (cell->string (vector-ref c i) 20)))
                         ", "))
                  (s (string-append "$ " (string-pad-right (symbol->string n) w) " "
                                    (string-pad-right t 6) " " vals)))
             (write-string (if (> (string-length s) 100) (string-append (substring s 0 99) "…") s)
                           port)
             (newline port)))
         (df-names df) (%df-cols df))))))
