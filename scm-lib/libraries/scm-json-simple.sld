(define-library (scm json simple)
  (import (scm core)
          (scheme base)
          (scheme char)
          (srfi 13))
  (export json-parse
          json-read
          json->string
          json->pretty-string
          json-write
          json-write-pretty
          json-null?
          json-ref)
  (begin

    ;; ================================================================
    ;; (scm json simple) — a high-level JSON codec mapping JSON to and
    ;; from ordinary Scheme data (sexps). It complements the low-level
    ;; streaming reader in (scm json): this one parses a whole document
    ;; into a value you can walk, and — unlike (scm json) — can also
    ;; serialize a value back to JSON, with optional pretty-printing.
    ;;
    ;; Representation:
    ;;   object     <-> alist ((string . value) ...), order preserved; '() is {}
    ;;   array      <-> vector #(v ...);  #() is []
    ;;   string     <-> string
    ;;   number     <-> exact integer when integral, else inexact real
    ;;   true/false <-> #t / #f
    ;;   null       <-> the symbol 'null  (test with json-null?)
    ;;
    ;; Objects are alists and arrays are vectors so the two never alias:
    ;; any list is an object, any vector an array. json->string and
    ;; json->pretty-string round-trip a parsed value back to equivalent
    ;; JSON; json->pretty-string uses two-space indentation.
    ;; ================================================================

    (define (json-parse str)
      "Syntax: (json-parse str)
Library: (scm json simple)
Description: Parses the JSON text in string str and returns its Scheme
  representation: objects as alists with string keys (order preserved),
  arrays as vectors, strings as strings, integral numbers as exact
  integers and fractional ones as inexact reals, true/false as #t/#f,
  and null as the symbol 'null. Raises an error on malformed input.
Example:
  (json-parse \"{\\\"a\\\": [1, 2.5, true, null]}\")
    => ((\"a\" . #(1 2.5 #t null)))"
      (let ((len (string-length str))
            (pos 0))
        (define (peek) (if (< pos len) (string-ref str pos) #f))
        (define (next) (let ((c (string-ref str pos))) (set! pos (+ pos 1)) c))
        (define (skip-ws)
          (let loop ()
            (let ((c (peek)))
              (when (and c (char-whitespace? c)) (next) (loop)))))
        (define (jerr msg) (error (string-append "json: " msg)))
        (define (expect ch)
          (skip-ws)
          (if (eqv? (peek) ch) (next) (jerr (string-append "expected " (string ch)))))
        (define (parse-value)
          (skip-ws)
          (let ((c (peek)))
            (cond
              ((not c) (jerr "unexpected end of input"))
              ((char=? c #\{) (parse-object))
              ((char=? c #\[) (parse-array))
              ((char=? c #\") (parse-string))
              ((or (char=? c #\-) (char-numeric? c)) (parse-number))
              ((char=? c #\t) (parse-lit "true" #t))
              ((char=? c #\f) (parse-lit "false" #f))
              ((char=? c #\n) (parse-lit "null" 'null))
              (else (jerr (string-append "unexpected char " (string c)))))))
        (define (parse-lit word val)
          (let loop ((i 0))
            (if (= i (string-length word))
                val
                (if (eqv? (peek) (string-ref word i))
                    (begin (next) (loop (+ i 1)))
                    (jerr (string-append "expected " word))))))
        (define (parse-object)
          (next)
          (skip-ws)
          (if (eqv? (peek) #\})
              (begin (next) '())
              (let loop ((acc '()))
                (skip-ws)
                (let ((key (parse-string)))
                  (expect #\:)
                  (let ((val (parse-value)))
                    (skip-ws)
                    (let ((c (peek)))
                      (cond
                        ((eqv? c #\,) (next) (loop (cons (cons key val) acc)))
                        ((eqv? c #\}) (next) (reverse (cons (cons key val) acc)))
                        (else (jerr "expected , or }")))))))))
        (define (parse-array)
          (next)
          (skip-ws)
          (if (eqv? (peek) #\])
              (begin (next) #())
              (let loop ((acc '()))
                (let ((val (parse-value)))
                  (skip-ws)
                  (let ((c (peek)))
                    (cond
                      ((eqv? c #\,) (next) (loop (cons val acc)))
                      ((eqv? c #\]) (next) (list->vector (reverse (cons val acc))))
                      (else (jerr "expected , or ]"))))))))
        (define (parse-string)
          (skip-ws)
          (unless (eqv? (peek) #\") (jerr "expected string"))
          (next)
          (let ((out (open-output-string)))
            (let loop ()
              (let ((c (next)))
                (cond
                  ((char=? c #\") (get-output-string out))
                  ((char=? c #\\)
                   (let ((e (next)))
                     (cond
                       ((char=? e #\") (write-char #\" out) (loop))
                       ((char=? e #\\) (write-char #\\ out) (loop))
                       ((char=? e #\/) (write-char #\/ out) (loop))
                       ((char=? e #\b) (write-char #\backspace out) (loop))
                       ((char=? e #\f) (write-char #\x0c out) (loop))
                       ((char=? e #\n) (write-char #\newline out) (loop))
                       ((char=? e #\r) (write-char #\return out) (loop))
                       ((char=? e #\t) (write-char #\tab out) (loop))
                       ((char=? e #\u)
                        (let ((cp (parse-hex4)))
                          (if (and (>= cp #xD800) (<= cp #xDBFF))
                              (begin
                                (unless (eqv? (peek) #\\) (jerr "expected low surrogate"))
                                (next)
                                (unless (eqv? (peek) #\u) (jerr "expected \\u low surrogate"))
                                (next)
                                (let ((lo (parse-hex4)))
                                  (write-char (integer->char
                                               (+ #x10000 (* (- cp #xD800) #x400) (- lo #xDC00)))
                                              out)))
                              (write-char (integer->char cp) out))
                          (loop)))
                       (else (jerr "bad escape")))))
                  (else (write-char c out) (loop)))))))
        (define (parse-hex4)
          (let loop ((i 0) (acc 0))
            (if (= i 4) acc (loop (+ i 1) (+ (* acc 16) (hex-digit (next)))))))
        (define (hex-digit c)
          (cond
            ((char<=? #\0 c #\9) (- (char->integer c) (char->integer #\0)))
            ((char<=? #\a c #\f) (+ 10 (- (char->integer c) (char->integer #\a))))
            ((char<=? #\A c #\F) (+ 10 (- (char->integer c) (char->integer #\A))))
            (else (jerr "bad hex digit"))))
        (define (parse-number)
          (let ((start pos))
            (when (eqv? (peek) #\-) (next))
            (let loop () (when (and (peek) (char-numeric? (peek))) (next) (loop)))
            (when (eqv? (peek) #\.)
              (next)
              (let loop () (when (and (peek) (char-numeric? (peek))) (next) (loop))))
            (when (or (eqv? (peek) #\e) (eqv? (peek) #\E))
              (next)
              (when (or (eqv? (peek) #\+) (eqv? (peek) #\-)) (next))
              (let loop () (when (and (peek) (char-numeric? (peek))) (next) (loop))))
            ;; string->number gives an exact integer for integral text and an
            ;; inexact real when a '.' or exponent is present.
            (string->number (substring str start pos))))
        (let ((result (parse-value))) (skip-ws) result)))

    (define (json-read port)
      "Syntax: (json-read port)
Library: (scm json simple)
Description: Reads the entire textual input port to a string and parses it
  as a single JSON document (see json-parse). Returns the eof object if the
  port is empty.
Example:
  (json-read (open-input-string \"[1, 2, 3]\")) => #(1 2 3)"
      (let ((out (open-output-string)))
        (let loop ((any #f))
          (let ((c (read-char port)))
            (if (eof-object? c)
                (if any (json-parse (get-output-string out)) (eof-object))
                (begin (write-char c out) (loop #t)))))))

    (define (json-write val port)
      "Syntax: (json-write val port)
Library: (scm json simple)
Description: Writes val to the output port as compact JSON (no insignificant
  whitespace). val must use the representation documented for this library
  (alists for objects, vectors for arrays, 'null for null).
Example:
  (json-write '((\"a\" . 1)) (current-output-port))  ; prints {\"a\":1}"
      (cond
        ((eq? val 'null) (write-string "null" port))
        ((eq? val #t) (write-string "true" port))
        ((eq? val #f) (write-string "false" port))
        ((string? val) (json-write-string val port))
        ((number? val) (write-string (number->string val) port))
        ((vector? val) (json-write-array val port))
        ((or (null? val) (pair? val)) (json-write-object val port))
        (else (error "json-write: cannot serialize" val))))

    (define (json-write-string s port)
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

    (define (json-write-array vec port)
      (write-char #\[ port)
      (let ((n (vector-length vec)))
        (let loop ((i 0))
          (when (< i n)
            (when (> i 0) (write-char #\, port))
            (json-write (vector-ref vec i) port)
            (loop (+ i 1)))))
      (write-char #\] port))

    (define (json-write-object alist port)
      (write-char #\{ port)
      (let loop ((items alist) (first #t))
        (unless (null? items)
          (unless first (write-char #\, port))
          (json-write-string (caar items) port)
          (write-char #\: port)
          (json-write (cdar items) port)
          (loop (cdr items) #f)))
      (write-char #\} port))

    (define (json-write-pretty val port)
      "Syntax: (json-write-pretty val port)
Library: (scm json simple)
Description: Writes val to the output port as indented JSON using two spaces
  per level — byte-compatible with the common 2-space pretty style. Same
  value representation as json-write.
Example:
  (json-write-pretty '((\"a\" . 1)) (current-output-port))
    ; prints {\\n  \"a\": 1\\n}"
      (define (indent n) (make-string (* 2 n) #\space))
      (define (go val depth)
        (cond
          ((vector? val)
           (let ((n (vector-length val)))
             (if (= n 0)
                 (write-string "[]" port)
                 (begin
                   (write-string "[\n" port)
                   (let loop ((i 0))
                     (when (< i n)
                       (write-string (indent (+ depth 1)) port)
                       (go (vector-ref val i) (+ depth 1))
                       (when (< i (- n 1)) (write-char #\, port))
                       (write-char #\newline port)
                       (loop (+ i 1))))
                   (write-string (indent depth) port)
                   (write-char #\] port)))))
          ((or (pair? val) (null? val))
           (if (null? val)
               (write-string "{}" port)
               (begin
                 (write-string "{\n" port)
                 (let loop ((items val))
                   (unless (null? items)
                     (write-string (indent (+ depth 1)) port)
                     (json-write-string (caar items) port)
                     (write-string ": " port)
                     (go (cdar items) (+ depth 1))
                     (unless (null? (cdr items)) (write-char #\, port))
                     (write-char #\newline port)
                     (loop (cdr items))))
                 (write-string (indent depth) port)
                 (write-char #\} port))))
          (else (json-write val port))))
      (go val 0))

    (define (json->string val)
      "Syntax: (json->string val)
Library: (scm json simple)
Description: Returns compact JSON text for val as a string (see json-write).
Example:
  (json->string #(1 2 3)) => \"[1,2,3]\""
      (let ((p (open-output-string))) (json-write val p) (get-output-string p)))

    (define (json->pretty-string val)
      "Syntax: (json->pretty-string val)
Library: (scm json simple)
Description: Returns two-space-indented JSON text for val as a string
  (see json-write-pretty).
Example:
  (json->pretty-string '((\"a\" . 1))) => \"{\\n  \\\"a\\\": 1\\n}\""
      (let ((p (open-output-string))) (json-write-pretty val p) (get-output-string p)))

    (define (json-null? x)
      "Syntax: (json-null? x)
Library: (scm json simple)
Description: Returns #t if x is the value json-parse produces for JSON null
  (the symbol 'null), #f otherwise.
Example:
  (json-null? (json-parse \"null\")) => #t
  (json-null? #f) => #f"
      (eq? x 'null))

    (define (json-ref obj key . default)
      "Syntax: (json-ref obj key [default])
Library: (scm json simple)
Description: Looks key (a string) up in obj, a parsed JSON object (alist).
  Returns the associated value, or default if absent (or #f when no default
  is given).
Example:
  (json-ref '((\"a\" . 1) (\"b\" . 2)) \"b\") => 2
  (json-ref '((\"a\" . 1)) \"z\" 'missing) => missing"
      (let ((p (and (pair? obj) (assoc key obj))))
        (cond (p (cdr p))
              ((pair? default) (car default))
              (else #f))))
))
