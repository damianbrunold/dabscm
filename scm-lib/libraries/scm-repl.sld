(define-library (scm repl)
  (import (scheme base)
          (scheme char)
          (scheme cxr)
          (scheme write)
          (scm module)
          (scm doc))
  (export repl-completions
          repl-syntax-info
          repl-info-line
          repl-core-form-names)
  (begin

    ;; ---------- helpers ----------

    (define (->str x)
      (cond ((string? x) x)
            ((symbol? x) (symbol->string x))
            (else
             (let ((p (open-output-string)))
               (write x p)
               (get-output-string p)))))

    (define (str-prefix? prefix s)
      (let ((np (string-length prefix))
            (ns (string-length s)))
        (and (<= np ns)
             (let loop ((i 0))
               (cond ((= i np) #t)
                     ((char=? (string-ref prefix i) (string-ref s i))
                      (loop (+ i 1)))
                     (else #f))))))

    (define (split-lines s)
      (let ((n (string-length s)))
        (let loop ((i 0) (start 0) (acc '()))
          (cond ((= i n)
                 (reverse (cons (substring s start n) acc)))
                ((char=? (string-ref s i) #\newline)
                 (loop (+ i 1) (+ i 1)
                       (cons (substring s start i) acc)))
                (else (loop (+ i 1) start acc))))))

    (define (trim s)
      (let ((n (string-length s)))
        (let scan-l ((i 0))
          (cond ((= i n) "")
                ((char-whitespace? (string-ref s i)) (scan-l (+ i 1)))
                (else
                 (let scan-r ((j n))
                   (cond ((<= j i) (substring s i j))
                         ((char-whitespace? (string-ref s (- j 1)))
                          (scan-r (- j 1)))
                         (else (substring s i j)))))))))

    (define (drop-prefix s p)
      (substring s (string-length p) (string-length s)))

    ;; insertion-sort over short string lists; the binding list is already
    ;; sorted from %module-bindings, so this only matters when we merge in
    ;; core forms — n is small either way.
    (define (str-sort lst)
      (define (insert x sorted)
        (cond ((null? sorted) (list x))
              ((string<? x (car sorted)) (cons x sorted))
              ((string=? x (car sorted)) sorted)
              (else (cons (car sorted) (insert x (cdr sorted))))))
      (let loop ((in lst) (out '()))
        (if (null? in) out
            (loop (cdr in) (insert (car in) out)))))

    ;; ---------- core form names ----------

    (define repl-core-form-names
      '("quote" "quasiquote" "unquote" "unquote-splicing"
        "if" "set!" "begin" "lambda" "case-lambda"
        "define" "define-values" "define-syntax" "define-record-type"
        "let" "let*" "letrec" "letrec*"
        "let-values" "let*-values"
        "let-syntax" "letrec-syntax"
        "and" "or" "when" "unless" "cond" "case" "do"
        "delay" "delay-force" "make-promise" "parameterize"
        "guard" "syntax-rules" "syntax-case"
        "include" "include-ci" "cond-expand"
        "define-library" "import" "export"))

    ;; ---------- visible-names + completions ----------

    (define (defined-names)
      (map ->str (%module-bindings (current-module))))

    (define (visible-names)
      (str-sort (append (defined-names) repl-core-form-names)))

    (define (repl-completions prefix)
      (let ((prefix (->str prefix))
            (names (visible-names)))
        (let loop ((ns names) (acc '()))
          (cond ((null? ns) (reverse acc))
                ((str-prefix? prefix (car ns))
                 (loop (cdr ns) (cons (car ns) acc)))
                (else (loop (cdr ns) acc))))))

    ;; ---------- doc lookup ----------

    (define (lookup-doc name-str)
      ;; Try current-module first. Fall back to false on any error.
      (guard (exn (#t #f))
        (let* ((mod (current-module))
               (sym (string->symbol name-str)))
          (if (not (member sym (%module-bindings mod)))
              #f
              (let ((val (%module-ref mod sym)))
                (procedure-doc val))))))

    (define (extract-syntax doc)
      (if (not (string? doc))
          #f
          (let loop ((ls (split-lines doc)) (acc '()))
            (cond ((null? ls)
                   (if (null? acc) #f (apply string-append-with-sep " | " (reverse acc))))
                  ((str-prefix? "Syntax:" (car ls))
                   (loop (cdr ls)
                         (cons (trim (drop-prefix (car ls) "Syntax:")) acc)))
                  ((null? acc)
                   (loop (cdr ls) acc))
                  (else
                   (apply string-append-with-sep " | " (reverse acc)))))))

    (define (string-append-with-sep sep . parts)
      (cond ((null? parts) "")
            ((null? (cdr parts)) (car parts))
            (else
             (let loop ((rest (cdr parts)) (out (car parts)))
               (if (null? rest) out
                   (loop (cdr rest) (string-append out sep (car rest))))))))

    (define (first-meaningful-line doc)
      (let loop ((ls (split-lines doc)))
        (cond ((null? ls) "")
              ((or (str-prefix? "Syntax:" (car ls))
                   (str-prefix? "Library:" (car ls))
                   (= 0 (string-length (trim (car ls)))))
               (loop (cdr ls)))
              ((str-prefix? "Description:" (car ls))
               (trim (drop-prefix (car ls) "Description:")))
              (else (trim (car ls))))))

    (define (repl-syntax-info name)
      (let* ((name (->str name))
             (doc (lookup-doc name)))
        (cond ((not doc) #f)
              ((not (string? doc)) (list name "" ""))
              (else
               (let ((sig (or (extract-syntax doc) ""))
                     (fl (first-meaningful-line doc)))
                 (list name sig fl))))))

    (define (repl-info-line name)
      (let ((info (repl-syntax-info name)))
        (if (not info) ""
            (let ((n (car info))
                  (sig (cadr info))
                  (fl (caddr info)))
              (cond ((and (> (string-length sig) 0) (> (string-length fl) 0))
                     (string-append n " : " sig " -- " fl))
                    ((> (string-length sig) 0)
                     (string-append n " : " sig))
                    ((> (string-length fl) 0)
                     (string-append n " -- " fl))
                    (else n))))))

    ))
