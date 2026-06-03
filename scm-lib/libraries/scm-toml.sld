(define-library (scm toml)
  (import (scm core)
          (scheme base)
          (scheme char)
          (scheme inexact)
          (srfi 13))
  (export toml-parse
          toml-read
          toml->string
          toml-write
          toml-ref
          make-toml-datetime
          toml-datetime?
          toml-datetime-kind
          toml-datetime-text)
  (begin

    ;; ================================================================
    ;; (scm toml) — a TOML 1.0 codec mapping TOML to and from ordinary
    ;; Scheme data (sexps). toml-parse / toml-read turn a whole document
    ;; into a value you can walk; toml->string / toml-write serialize a
    ;; value back to TOML text.
    ;;
    ;; Representation:
    ;;   table      <-> alist ((string-key . value) ...), order preserved;
    ;;                  the empty table is '(); a document parses to a table
    ;;   array      <-> vector #(v ...);  #() is []
    ;;   string     <-> string
    ;;   integer    <-> exact integer (dec / 0x / 0o / 0b, '_' separators)
    ;;   float      <-> inexact real (inf and nan included)
    ;;   boolean    <-> #t / #f
    ;;   date-time  <-> a toml-datetime record (see make-toml-datetime),
    ;;                  carrying its kind and the raw RFC 3339 text
    ;;
    ;; Tables are alists and arrays are vectors so the two never alias:
    ;; any list is a table, any vector an array. An array whose elements
    ;; are all (non-empty) tables is written as a TOML array of tables
    ;; ([[name]]); other arrays are written inline. toml->string and
    ;; toml-write round-trip a parsed value back to equivalent TOML.
    ;; ================================================================

    ;; ---- date-time values ------------------------------------------

    (define-record-type toml-datetime
      (make-toml-datetime kind text)
      toml-datetime?
      (kind toml-datetime-kind)
      (text toml-datetime-text))

    ;; ---- internal mutable tables used while parsing -----------------
    ;;
    ;; A document is assembled into mtable/aot nodes (which support the
    ;; in-place growth that [table] and [[array]] headers need) and only
    ;; converted to the final alist/vector representation at the very end.

    (define-record-type mtable
      (mk-mtable entries)
      mtable?
      (entries mt-entries mt-set-entries!))

    (define-record-type aot
      (mk-aot tables)
      aot?
      (tables aot-tables aot-set-tables!))

    (define (mt-find mt key) (assoc key (mt-entries mt)))

    (define (mt-put! mt key val)
      (let ((p (mt-find mt key)))
        (if p
            (set-cdr! p val)
            (mt-set-entries! mt (append (mt-entries mt) (list (cons key val)))))))

    ;; ---- the parser -------------------------------------------------

    (define (toml-parse str)
      "Syntax: (toml-parse str)
Library: (scm toml)
Description: Parses the TOML text in string str and returns its Scheme
  representation: tables as alists with string keys (order preserved),
  arrays as vectors, strings as strings, integers as exact integers, floats
  as inexact reals, booleans as #t/#f, and dates/times as toml-datetime
  values. The result of a whole document is always a table. Raises an error
  on malformed input.
Example:
  (toml-parse \"title = \\\"TOML\\\"\\n[owner]\\nname = \\\"Tom\\\"\")
    => ((\"title\" . \"TOML\") (\"owner\" (\"name\" . \"Tom\")))"
      (let ((len (string-length str))
            (pos 0))

        (define (peek) (if (< pos len) (string-ref str pos) #f))
        (define (peek-at k) (if (< (+ pos k) len) (string-ref str (+ pos k)) #f))
        (define (next) (let ((c (string-ref str pos))) (set! pos (+ pos 1)) c))
        (define (next-or-err)
          (if (< pos len) (next) (terr "unexpected end of input")))
        (define (terr . args) (apply error (cons "toml:" args)))

        (define (digit? c) (and c (char<=? #\0 c #\9)))
        (define (digit-at? k) (digit? (peek-at k)))
        (define (hex-char? c)
          (and c (or (char<=? #\0 c #\9) (char<=? #\a c #\f) (char<=? #\A c #\F))))
        (define (bare-key-char? c)
          (and c (or (char<=? #\a c #\z) (char<=? #\A c #\Z) (char<=? #\0 c #\9)
                     (char=? c #\_) (char=? c #\-))))

        (define (read-while pred)
          (let loop () (when (pred (peek)) (next) (loop))))

        (define (skip-inline-ws)
          (read-while (lambda (c) (and c (or (char=? c #\space) (char=? c #\tab))))))

        (define (skip-comment)
          ;; assumes current char is '#'; consumes through end of line text
          (read-while (lambda (c) (and c (not (char=? c #\newline)) (not (char=? c #\return))))))

        (define (skip-blanks)
          ;; skip inter-statement whitespace: spaces, tabs, newlines and comments
          (let loop ()
            (let ((c (peek)))
              (cond
                ((not c) #f)
                ((or (char=? c #\space) (char=? c #\tab)
                     (char=? c #\newline) (char=? c #\return))
                 (next) (loop))
                ((char=? c #\#) (skip-comment) (loop))
                (else #f)))))

        (define (skip-array-ws)
          ;; within arrays, newlines and comments are insignificant
          (skip-blanks))

        (define (expect ch)
          (skip-inline-ws)
          (if (eqv? (peek) ch)
              (next)
              (terr (string-append "expected " (string ch)))))

        ;; ---- strings ----

        (define (read-hex n)
          (let loop ((i 0) (acc 0))
            (if (= i n)
                acc
                (let ((c (next-or-err)))
                  (cond
                    ((char<=? #\0 c #\9) (loop (+ i 1) (+ (* acc 16) (- (char->integer c) 48))))
                    ((char<=? #\a c #\f) (loop (+ i 1) (+ (* acc 16) (+ 10 (- (char->integer c) 97)))))
                    ((char<=? #\A c #\F) (loop (+ i 1) (+ (* acc 16) (+ 10 (- (char->integer c) 65)))))
                    (else (terr "bad hex digit in escape")))))))

        (define (read-escape out ml?)
          (let ((e (next-or-err)))
            (cond
              ((char=? e #\") (write-char #\" out))
              ((char=? e #\\) (write-char #\\ out))
              ((char=? e #\b) (write-char #\backspace out))
              ((char=? e #\t) (write-char #\tab out))
              ((char=? e #\n) (write-char #\newline out))
              ((char=? e #\f) (write-char #\x0c out))
              ((char=? e #\r) (write-char #\return out))
              ((char=? e #\u) (write-char (integer->char (read-hex 4)) out))
              ((char=? e #\U) (write-char (integer->char (read-hex 8)) out))
              ((and ml? (or (char=? e #\space) (char=? e #\tab)
                            (char=? e #\newline) (char=? e #\return)))
               ;; line-ending backslash: trim it and all following whitespace
               (read-while (lambda (c)
                             (and c (or (char=? c #\space) (char=? c #\tab)
                                        (char=? c #\newline) (char=? c #\return))))))
              (else (terr "bad string escape" (string e))))))

        (define (parse-basic-string)
          (next) ; opening "
          (if (and (eqv? (peek) #\") (eqv? (peek-at 1) #\"))
              (begin (next) (next) (parse-ml-basic))
              (let ((out (open-output-string)))
                (let loop ()
                  (let ((c (next-or-err)))
                    (cond
                      ((char=? c #\") (get-output-string out))
                      ((or (char=? c #\newline) (char=? c #\return))
                       (terr "newline in basic string"))
                      ((char=? c #\\) (read-escape out #f) (loop))
                      (else (write-char c out) (loop))))))))

        (define (parse-ml-basic)
          (when (eqv? (peek) #\return) (next))
          (when (eqv? (peek) #\newline) (next))
          (let ((out (open-output-string)))
            (let loop ()
              (if (and (eqv? (peek) #\") (eqv? (peek-at 1) #\") (eqv? (peek-at 2) #\"))
                  (begin (next) (next) (next) (get-output-string out))
                  (let ((c (next-or-err)))
                    (if (char=? c #\\)
                        (begin (read-escape out #t) (loop))
                        (begin (write-char c out) (loop))))))))

        (define (parse-literal-string)
          (next) ; opening '
          (if (and (eqv? (peek) #\') (eqv? (peek-at 1) #\'))
              (begin (next) (next) (parse-ml-literal))
              (let ((out (open-output-string)))
                (let loop ()
                  (let ((c (next-or-err)))
                    (cond
                      ((char=? c #\') (get-output-string out))
                      ((or (char=? c #\newline) (char=? c #\return))
                       (terr "newline in literal string"))
                      (else (write-char c out) (loop))))))))

        (define (parse-ml-literal)
          (when (eqv? (peek) #\return) (next))
          (when (eqv? (peek) #\newline) (next))
          (let ((out (open-output-string)))
            (let loop ()
              (if (and (eqv? (peek) #\') (eqv? (peek-at 1) #\') (eqv? (peek-at 2) #\'))
                  (begin (next) (next) (next) (get-output-string out))
                  (begin (write-char (next-or-err) out) (loop))))))

        ;; ---- keys ----

        (define (parse-simple-key)
          (let ((c (peek)))
            (cond
              ((eqv? c #\") (parse-basic-string))
              ((eqv? c #\') (parse-literal-string))
              ((bare-key-char? c)
               (let ((out (open-output-string)))
                 (let loop ()
                   (if (bare-key-char? (peek))
                       (begin (write-char (next) out) (loop))
                       (get-output-string out)))))
              (else (terr "expected a key")))))

        (define (parse-key)
          ;; returns a list of key strings (a dotted path is split here)
          (skip-inline-ws)
          (let loop ((keys '()))
            (let ((k (parse-simple-key)))
              (skip-inline-ws)
              (if (eqv? (peek) #\.)
                  (begin (next) (skip-inline-ws) (loop (cons k keys)))
                  (reverse (cons k keys))))))

        ;; ---- numbers and date-times ----

        (define (strip-underscores s)
          (let ((out (open-output-string)))
            (string-for-each
              (lambda (c) (unless (char=? c #\_) (write-char c out)))
              s)
            (get-output-string out)))

        (define (parse-literal-word word)
          ;; consume exactly the characters of word, erroring otherwise
          (let loop ((i 0))
            (if (= i (string-length word))
                #t
                (if (eqv? (peek) (string-ref word i))
                    (begin (next) (loop (+ i 1)))
                    (terr (string-append "expected " word))))))

        (define (parse-number)
          (let ((start pos))
            (when (memv (peek) '(#\+ #\-)) (next))
            (if (and (eqv? (peek) #\0) (memv (peek-at 1) '(#\x #\o #\b)))
                (let ((base-char (peek-at 1)))
                  (next) (next)
                  (let ((digit-start pos))
                    (read-while (lambda (c) (or (hex-char? c) (eqv? c #\_))))
                    (let* ((digits (strip-underscores (substring str digit-start pos)))
                           (base (cond ((eqv? base-char #\x) 16)
                                       ((eqv? base-char #\o) 8)
                                       (else 2)))
                           (n (string->number digits base)))
                      (or n (terr "bad number")))))
                (begin
                  (read-while (lambda (c)
                                (or (digit? c)
                                    (memv c '(#\_ #\. #\e #\E #\+ #\-)))))
                  (let* ((text (strip-underscores (substring str start pos)))
                         (n (string->number text)))
                    (or n (terr "bad number" text)))))))

        (define (datetime-ahead?)
          (or (and (digit-at? 0) (digit-at? 1) (digit-at? 2) (digit-at? 3)
                   (eqv? (peek-at 4) #\-))
              (and (digit-at? 0) (digit-at? 1) (eqv? (peek-at 2) #\:))))

        (define (parse-datetime)
          (let ((out (open-output-string))
                (has-date #f) (has-time #f) (has-offset #f))
            (define (emit c) (write-char c out))
            (define (take) (let ((c (next-or-err))) (emit c) c))
            (define (take-n n)
              (let loop ((i 0))
                (when (< i n)
                  (unless (digit? (peek)) (terr "bad date-time"))
                  (take) (loop (+ i 1)))))
            (define (take-lit ch)
              (unless (eqv? (peek) ch) (terr "bad date-time"))
              (take))
            (define (read-time)
              (take-n 2) (take-lit #\:) (take-n 2) (take-lit #\:) (take-n 2)
              (when (eqv? (peek) #\.)
                (take)
                (read-while digit?)) ; note: read-while takes char predicate
              (let ((c (peek)))
                (cond
                  ((or (eqv? c #\Z) (eqv? c #\z)) (take) (set! has-offset #t))
                  ((or (eqv? c #\+) (eqv? c #\-))
                   (take) (take-n 2) (take-lit #\:) (take-n 2) (set! has-offset #t)))))
            (if (and (digit-at? 0) (digit-at? 1) (eqv? (peek-at 2) #\:))
                (begin (set! has-time #t) (read-time))
                (begin
                  (set! has-date #t)
                  (take-n 4) (take-lit #\-) (take-n 2) (take-lit #\-) (take-n 2)
                  (let ((c (peek)))
                    (when (or (eqv? c #\T) (eqv? c #\t)
                              (and (eqv? c #\space) (digit-at? 1) (digit-at? 2)
                                   (eqv? (peek-at 3) #\:)))
                      (take) ; date/time separator
                      (set! has-time #t)
                      (read-time)))))
            (let ((kind (cond
                          ((and has-date has-time has-offset) 'offset-date-time)
                          ((and has-date has-time) 'local-date-time)
                          (has-date 'local-date)
                          (else 'local-time))))
              (make-toml-datetime kind (get-output-string out)))))

        ;; ---- values ----

        (define (parse-value)
          (let ((c (peek)))
            (cond
              ((not c) (terr "unexpected end of input"))
              ((char=? c #\") (parse-basic-string))
              ((char=? c #\') (parse-literal-string))
              ((char=? c #\[) (parse-array))
              ((char=? c #\{) (parse-inline-table))
              ((char=? c #\t) (parse-literal-word "true") #t)
              ((char=? c #\f) (parse-literal-word "false") #f)
              ((char=? c #\i) (parse-literal-word "inf") +inf.0)
              ((char=? c #\n) (parse-literal-word "nan") +nan.0)
              ((or (char=? c #\+) (char=? c #\-))
               (let ((d (peek-at 1)))
                 (cond
                   ((eqv? d #\i) (next) (parse-literal-word "inf")
                                 (if (char=? c #\-) -inf.0 +inf.0))
                   ((eqv? d #\n) (next) (parse-literal-word "nan") +nan.0)
                   (else (parse-number)))))
              ((digit? c) (if (datetime-ahead?) (parse-datetime) (parse-number)))
              (else (terr "unexpected character" (string c))))))

        (define (parse-array)
          (next) ; [
          (let loop ((acc '()))
            (skip-array-ws)
            (let ((c (peek)))
              (cond
                ((not c) (terr "unterminated array"))
                ((char=? c #\]) (next) (list->vector (reverse acc)))
                (else
                 (let ((v (parse-value)))
                   (skip-array-ws)
                   (let ((c2 (peek)))
                     (cond
                       ((eqv? c2 #\,) (next) (loop (cons v acc)))
                       ((eqv? c2 #\]) (next) (list->vector (reverse (cons v acc))))
                       (else (terr "expected , or ] in array"))))))))))

        (define (parse-inline-table)
          (next) ; {
          (skip-inline-ws)
          (let ((mt (mk-mtable '())))
            (if (eqv? (peek) #\})
                (begin (next) (mtable->value mt))
                (let loop ()
                  (skip-inline-ws)
                  (let ((path (parse-key)))
                    (skip-inline-ws) (expect #\=) (skip-inline-ws)
                    (assign! mt path (parse-value))
                    (skip-inline-ws)
                    (let ((c (peek)))
                      (cond
                        ((eqv? c #\,) (next) (loop))
                        ((eqv? c #\}) (next) (mtable->value mt))
                        (else (terr "expected , or } in inline table")))))))))

        ;; ---- table navigation ----

        (define (get-or-make-subtable mt key)
          (let ((p (mt-find mt key)))
            (cond
              ((not p) (let ((sub (mk-mtable '()))) (mt-put! mt key sub) sub))
              ((mtable? (cdr p)) (cdr p))
              ((aot? (cdr p))
               (let ((ts (aot-tables (cdr p))))
                 (if (null? ts)
                     (terr "empty array of tables" key)
                     (car (reverse ts)))))
              (else (terr "key is not a table" key)))))

        (define (descend mt keys)
          (if (null? keys)
              mt
              (descend (get-or-make-subtable mt (car keys)) (cdr keys))))

        (define (but-last lst)
          (if (null? (cdr lst)) '() (cons (car lst) (but-last (cdr lst)))))

        (define (last-of lst) (car (reverse lst)))

        (define (assign! current path val)
          (let ((mt (descend current (but-last path)))
                (key (last-of path)))
            (if (mt-find mt key)
                (terr "duplicate key" key)
                (mt-put! mt key val))))

        (define (open-array-of-tables root path)
          (let* ((parent (descend root (but-last path)))
                 (key (last-of path))
                 (p (mt-find parent key)))
            (cond
              ((not p)
               (let* ((nt (mk-mtable '())) (a (mk-aot (list nt))))
                 (mt-put! parent key a)
                 nt))
              ((aot? (cdr p))
               (let ((nt (mk-mtable '())))
                 (aot-set-tables! (cdr p) (append (aot-tables (cdr p)) (list nt)))
                 nt))
              (else (terr "key is not an array of tables" key)))))

        ;; ---- convert internal nodes to the final representation ----

        (define (mtable->value mt)
          (map (lambda (e) (cons (car e) (node->value (cdr e)))) (mt-entries mt)))

        (define (node->value n)
          (cond
            ((mtable? n) (mtable->value n))
            ((aot? n) (list->vector (map mtable->value (aot-tables n))))
            (else n)))

        ;; ---- document driver ----

        (define (finish-line)
          (skip-inline-ws)
          (when (eqv? (peek) #\#) (skip-comment))
          (let ((c (peek)))
            (cond
              ((not c) #t)
              ((char=? c #\newline) (next))
              ((char=? c #\return) (next) (when (eqv? (peek) #\newline) (next)))
              (else (terr "expected end of line" (string c))))))

        (let ((root (mk-mtable '()))
              (current #f))
          (set! current root)
          (let loop ()
            (skip-blanks)
            (let ((c (peek)))
              (cond
                ((not c) (mtable->value root))
                ((char=? c #\[)
                 (if (eqv? (peek-at 1) #\[)
                     (begin
                       (next) (next)
                       (let ((path (parse-key)))
                         (expect #\]) (expect #\])
                         (set! current (open-array-of-tables root path))
                         (finish-line)
                         (loop)))
                     (begin
                       (next)
                       (let ((path (parse-key)))
                         (expect #\])
                         (set! current (descend root path))
                         (finish-line)
                         (loop)))))
                (else
                 (let ((path (parse-key)))
                   (skip-inline-ws) (expect #\=) (skip-inline-ws)
                   (assign! current path (parse-value))
                   (finish-line)
                   (loop)))))))))

    (define (toml-read port)
      "Syntax: (toml-read port)
Library: (scm toml)
Description: Reads the entire textual input port to a string and parses it
  as a single TOML document (see toml-parse). Returns the eof object if the
  port is empty.
Example:
  (toml-read (open-input-string \"a = 1\")) => ((\"a\" . 1))"
      (let ((out (open-output-string)))
        (let loop ((any #f))
          (let ((c (read-char port)))
            (if (eof-object? c)
                (if any (toml-parse (get-output-string out)) (eof-object))
                (begin (write-char c out) (loop #t)))))))

    ;; ---- the writer -------------------------------------------------

    (define (bare-key-string? s)
      (and (> (string-length s) 0)
           (string-every
             (lambda (c) (or (char<=? #\a c #\z) (char<=? #\A c #\Z)
                             (char<=? #\0 c #\9) (char=? c #\_) (char=? c #\-)))
             s)))

    (define (write-key-string s port)
      (if (bare-key-string? s)
          (write-string s port)
          (write-basic-string s port)))

    (define (path->string keys)
      (let ((p (open-output-string)))
        (let loop ((ks keys) (first #t))
          (unless (null? ks)
            (unless first (write-char #\. p))
            (write-key-string (car ks) p)
            (loop (cdr ks) #f)))
        (get-output-string p)))

    (define (write-basic-string s port)
      (write-char #\" port)
      (string-for-each
        (lambda (c)
          (cond
            ((char=? c #\") (write-string "\\\"" port))
            ((char=? c #\\) (write-string "\\\\" port))
            ((char=? c #\newline) (write-string "\\n" port))
            ((char=? c #\return) (write-string "\\r" port))
            ((char=? c #\tab) (write-string "\\t" port))
            ((char=? c #\backspace) (write-string "\\b" port))
            ((char=? c #\x0c) (write-string "\\f" port))
            ((< (char->integer c) #x20)
             (write-string "\\u" port)
             (write-string (string-pad (number->string (char->integer c) 16) 4 #\0) port))
            (else (write-char c port))))
        s)
      (write-char #\" port))

    (define (table-value? x) (or (pair? x) (null? x)))

    (define (array-of-tables? x)
      (and (vector? x)
           (> (vector-length x) 0)
           (let loop ((i 0))
             (cond
               ((= i (vector-length x)) #t)
               ((pair? (vector-ref x i)) (loop (+ i 1)))
               (else #f)))))

    (define (write-float v port)
      (cond
        ((nan? v) (write-string "nan" port))
        ((infinite? v) (write-string (if (positive? v) "inf" "-inf") port))
        (else (write-string (number->string v) port))))

    (define (write-scalar v port)
      ;; values that appear after `key = ` or inside an inline array/table
      (cond
        ((eq? v #t) (write-string "true" port))
        ((eq? v #f) (write-string "false" port))
        ((toml-datetime? v) (write-string (toml-datetime-text v) port))
        ((and (number? v) (exact? v) (integer? v)) (write-string (number->string v) port))
        ((number? v) (write-float v port))
        ((string? v) (write-basic-string v port))
        ((vector? v) (write-inline-array v port))
        ((table-value? v) (write-inline-table v port))
        (else (error "toml-write: cannot serialize" v))))

    (define (write-inline-array vec port)
      (write-char #\[ port)
      (let ((n (vector-length vec)))
        (let loop ((i 0))
          (when (< i n)
            (when (> i 0) (write-string ", " port))
            (write-scalar (vector-ref vec i) port)
            (loop (+ i 1)))))
      (write-char #\] port))

    (define (write-inline-table alist port)
      (write-char #\{ port)
      (let loop ((items alist) (first #t))
        (unless (null? items)
          (unless first (write-string ", " port))
          (write-char #\space port)
          (write-key-string (caar items) port)
          (write-string " = " port)
          (write-scalar (cdar items) port)
          (loop (cdr items) #f)))
      (unless (null? alist) (write-char #\space port))
      (write-char #\} port))

    (define (emit-table alist path port)
      ;; first pass: plain key/value lines (scalars and non-table arrays)
      (for-each
        (lambda (e)
          (let ((v (cdr e)))
            (unless (or (table-value? v) (array-of-tables? v))
              (write-key-string (car e) port)
              (write-string " = " port)
              (write-scalar v port)
              (write-char #\newline port))))
        alist)
      ;; second pass: sub-tables and arrays of tables, each as a header section
      (for-each
        (lambda (e)
          (let ((v (cdr e))
                (sub-path (append path (list (car e)))))
            (cond
              ((array-of-tables? v)
               (let ((n (vector-length v)))
                 (let loop ((i 0))
                   (when (< i n)
                     (write-char #\newline port)
                     (write-string "[[" port)
                     (write-string (path->string sub-path) port)
                     (write-string "]]" port)
                     (write-char #\newline port)
                     (emit-table (vector-ref v i) sub-path port)
                     (loop (+ i 1))))))
              ((table-value? v)
               (write-char #\newline port)
               (write-char #\[ port)
               (write-string (path->string sub-path) port)
               (write-char #\] port)
               (write-char #\newline port)
               (emit-table v sub-path port)))))
        alist))

    (define (toml-write val port)
      "Syntax: (toml-write val port)
Library: (scm toml)
Description: Writes val to the output port as TOML text. val must be a table
  (an alist with string keys) using the representation documented for this
  library. Scalar entries are emitted first, then nested tables as [header]
  sections and arrays of tables as [[header]] sections.
Example:
  (toml-write '((\"a\" . 1) (\"t\" (\"b\" . 2))) (current-output-port))
    ; prints  a = 1\\n\\n[t]\\nb = 2"
      (unless (table-value? val)
        (error "toml-write: top-level value must be a table" val))
      (emit-table val '() port))

    (define (toml->string val)
      "Syntax: (toml->string val)
Library: (scm toml)
Description: Returns TOML text for val (a table) as a string (see toml-write).
Example:
  (toml->string '((\"a\" . 1))) => \"a = 1\\n\""
      (let ((p (open-output-string))) (toml-write val p) (get-output-string p)))

    (define (toml-ref table key . default)
      "Syntax: (toml-ref table key [default])
Library: (scm toml)
Description: Looks key (a string) up in table, a parsed TOML table (alist).
  Returns the associated value, or default if absent (or #f when no default
  is given).
Example:
  (toml-ref '((\"a\" . 1) (\"b\" . 2)) \"b\") => 2
  (toml-ref '((\"a\" . 1)) \"z\" 'missing) => missing"
      (let ((p (and (pair? table) (assoc key table))))
        (cond (p (cdr p))
              ((pair? default) (car default))
              (else #f))))
))
