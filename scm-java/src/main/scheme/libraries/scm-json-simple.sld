(define-library (scm json simple)
  (import (scm core)
          (scheme base))
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

    ;; json-parse is a native primitive (see PrimitiveJsonSimpleParse); its
    ;; documentation lives in that primitive's info() method.
    (define json-parse (%primitive "json-simple-parse"))

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

    ;; json->string and json->pretty-string are native primitives (see
    ;; PrimitiveJsonSimpleToString / PrimitiveJsonSimpleToPrettyString); their
    ;; documentation lives in those primitives' info() methods.
    (define json->string (%primitive "json-simple->string"))
    (define json->pretty-string (%primitive "json-simple->pretty-string"))

    (define (json-write val port)
      "Syntax: (json-write val port)
Library: (scm json simple)
Description: Writes val to the output port as compact JSON (no insignificant
  whitespace). val must use the representation documented for this library
  (alists for objects, vectors for arrays, 'null for null).
Example:
  (json-write '((\"a\" . 1)) (current-output-port))  ; prints {\"a\":1}"
      (write-string (json->string val) port))

    (define (json-write-pretty val port)
      "Syntax: (json-write-pretty val port)
Library: (scm json simple)
Description: Writes val to the output port as indented JSON using two spaces
  per level — byte-compatible with the common 2-space pretty style. Same
  value representation as json-write.
Example:
  (json-write-pretty '((\"a\" . 1)) (current-output-port))
    ; prints {\\n  \"a\": 1\\n}"
      (write-string (json->pretty-string val) port))

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
