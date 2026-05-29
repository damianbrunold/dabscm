(define-library (scm system)
  (import (only (scm core) modules)
          (scheme base)
          (srfi 18))
  (export current-pid
          env-list
          get-environment-variable
          get-bytes
          getopt
          kill
          modules
          parent-pid
          pgrep
          pkill
          process-alive?
          process-kill
          process-pid
          process-wait
          ps
          ps-info
          run
          run!
          run?
          run-parallel
          run-program
          run-program/capture
          sh
          sh-lines
          shell-quote
          sleep
          start-program
          sys-machine-name
          sys-num-cpu-cores
          sys-os-version
          sys-platform
          sys-scm-technology
          sys-scm-version
          sys-user-name
          uuidgen
          watch)
  (begin
    (define get-environment-variable (%primitive "get-environment-variable"))
    (define %get-environment-variables (%primitive "get-environment-variables"))
    (define %random-bytes (%primitive "random-bytes"))
    (define %bytevector-u8-ref (%primitive "bytevector-u8-ref"))
    (define %bitwise-and (%primitive "bitwise-and"))
    (define %bitwise-ior (%primitive "bitwise-ior"))
    (define get-bytes (%primitive "get-bytes"))
    (define process-alive? (%primitive "process-alive?"))
    (define process-kill   (%primitive "process-kill"))
    (define process-pid    (%primitive "process-pid"))
    (define process-wait   (%primitive "process-wait"))
    (define current-pid    (%primitive "current-pid"))
    (define parent-pid     (%primitive "parent-pid"))
    (define ps             (%primitive "ps"))
    (define ps-info        (%primitive "ps-info"))
    (define pgrep          (%primitive "pgrep"))
    (define pkill          (%primitive "pkill"))
    (define kill           (%primitive "kill"))
    (define run-program (%primitive "run-program"))
    (define run-program/capture (%primitive "run-program/capture"))
    (define start-program (%primitive "start-program"))
    (define (run-parallel fn values)
      "Syntax: (run-parallel fn values)
Library: (scm system)
Description: Runs fn in parallel over each element of values using one thread per
  element and returns the results as a list in the same order. Exceptions raised
  in any thread are propagated when joining.
Example:
  (run-parallel (lambda (x) (* x x)) '(1 2 3 4)) => (1 4 9 16)"
      (let* ((threads (map (lambda (v)
                             (make-thread (lambda () (fn v))))
                           values))
             (_ (for-each thread-start! threads)))
        (map thread-join! threads)))
    (define sys-machine-name (%primitive "sys-machine-name"))
    (define sys-num-cpu-cores (%primitive "sys-num-cpu-cores"))
    (define sys-os-version (%primitive "sys-os-version"))
    (define sys-platform (%primitive "sys-platform"))
    (define sys-scm-technology (%primitive "sys-scm-technology"))
    (define sys-scm-version (%primitive "sys-scm-version"))
    (define sys-user-name (%primitive "sys-user-name"))

    (define (getopt argv spec)
      "Syntax: (getopt argv spec)
Library: (scm system)
Description: Parses command-line arguments. argv is a list of strings;
  spec is a list of option descriptors, each one of:
    (long-name short-char takes-value? [default])
  where long-name is a string (without the --), short-char is a character
  (or #f), takes-value? is a boolean, and default is the value used when
  the option is absent (defaults to #f for non-value flags, #f for
  value-taking options). Returns (alist . positionals) where alist maps
  long-name strings to the supplied values (#t for absent boolean flags
  is replaced by the default). Unknown options raise an error.
Example:
  (getopt '(\"-v\" \"--name\" \"foo\" \"a\" \"b\")
          '((\"verbose\" #\\v #f)
            (\"name\"    #\\n #t \"anon\")))
  => (((\"verbose\" . #t) (\"name\" . \"foo\")) . (\"a\" \"b\"))"
      (let loop ((args argv) (opts '()) (positional '()))
        (cond
          ((null? args)
           ;; fill in defaults for absent options
           (let ((complete
                  (map (lambda (s)
                         (let* ((name (car s))
                                (defv (if (>= (length s) 4) (list-ref s 3) #f))
                                (existing (assoc name opts)))
                           (cons name
                                 (if existing (cdr existing) defv))))
                       spec)))
             (cons complete (reverse positional))))
          (else
           (let ((a (car args)))
             (cond
               ((string=? a "--")
                ;; rest are positional
                (loop '() opts
                      (append (reverse (cdr args)) positional)))
               ((or (zero? (string-length a))
                    (not (char=? (string-ref a 0) #\-))
                    (= (string-length a) 1))
                ;; positional argument
                (loop (cdr args) opts (cons a positional)))
               ((and (>= (string-length a) 2)
                     (string=? (substring a 0 2) "--"))
                (let* ((name (substring a 2 (string-length a)))
                       (s (find-getopt-spec name spec #f)))
                  (cond
                    ((not s) (error "getopt: unknown option" a))
                    ((list-ref s 2)
                     (when (null? (cdr args))
                       (error "getopt: option requires value" a))
                     (loop (cddr args)
                           (cons (cons name (cadr args)) opts)
                           positional))
                    (else
                     (loop (cdr args) (cons (cons name #t) opts) positional)))))
               ((and (>= (string-length a) 2)
                     (char=? (string-ref a 0) #\-))
                ;; short option: -v or -nVALUE
                (let* ((c (string-ref a 1))
                       (s (find-getopt-spec #f spec c)))
                  (cond
                    ((not s) (error "getopt: unknown option" a))
                    ((list-ref s 2)
                     ;; takes value: rest of arg or next arg
                     (cond
                       ((> (string-length a) 2)
                        (loop (cdr args)
                              (cons (cons (car s)
                                          (substring a 2 (string-length a)))
                                    opts)
                              positional))
                       (else
                        (when (null? (cdr args))
                          (error "getopt: option requires value" a))
                        (loop (cddr args)
                              (cons (cons (car s) (cadr args)) opts)
                              positional))))
                    (else
                     (loop (cdr args) (cons (cons (car s) #t) opts) positional)))))
               (else
                (loop (cdr args) opts (cons a positional)))))))))

    (define (find-getopt-spec name spec short)
      (let loop ((s spec))
        (cond
          ((null? s) #f)
          ((and name (string=? (car (car s)) name)) (car s))
          ((and short
                (cadr (car s))
                (char=? (cadr (car s)) short))
           (car s))
          (else (loop (cdr s))))))

    (define (uuidgen)
      "Syntax: (uuidgen)
Library: (scm system)
Description: Returns a random RFC 4122 version 4 UUID as a string in
  canonical 8-4-4-4-12 hyphenated form. Uses cryptographically random
  bytes; version and variant bits are set per the spec.
Example:
  (uuidgen) => \"e3b0c442-98fc-4c14-9afb-f4ca495991b9\""
      (let* ((bv (%random-bytes 16))
             (b6 (%bytevector-u8-ref bv 6))
             (b8 (%bytevector-u8-ref bv 8)))
        ;; set version (4) and variant (10xx)
        (let ((nb6 (%bitwise-ior (%bitwise-and b6 #x0F) #x40))
              (nb8 (%bitwise-ior (%bitwise-and b8 #x3F) #x80)))
          ;; reassemble via hex helper to keep this dependency-free
          (let ((out (open-output-string)))
            (define (hex-byte b)
              (let* ((s (uuid-hex2 b)))
                (write-string s out)))
            (let loop ((i 0))
              (when (< i 16)
                (cond
                  ((or (= i 4) (= i 6) (= i 8) (= i 10))
                   (write-char #\- out)))
                (hex-byte (cond ((= i 6) nb6)
                                ((= i 8) nb8)
                                (else (%bytevector-u8-ref bv i))))
                (loop (+ i 1))))
            (get-output-string out)))))

    (define uuid-hex-chars "0123456789abcdef")
    (define (uuid-hex2 b)
      (string (string-ref uuid-hex-chars (quotient b 16))
              (string-ref uuid-hex-chars (modulo b 16))))

    (define (env-list)
      "Syntax: (env-list)
Library: (scm system)
Description: Returns an alist of all environment variables as (name . value)
  pairs. Equivalent to SRFI-98 get-environment-variables.
Example:
  (env-list) => ((\"PATH\" . \"/usr/bin\") ...)"
      (%get-environment-variables))

    (define (run prog . args)
      "Syntax: (run prog arg ...)
Library: (scm system)
Description: Varargs wrapper around run-program. Runs the external program
  prog with the given arguments and returns its exit code.
Example:
  (run \"echo\" \"hello\") => 0"
      (run-program (cons prog args)))

    (define (run! prog . args)
      "Syntax: (run! prog arg ...)
Library: (scm system)
Description: Like run, but raises an error when the program exits non-zero
  or fails to launch. Returns 0 on success.
Example:
  (run! \"true\") => 0"
      (let ((code (run-program (cons prog args))))
        (cond
          ((not code)
           (error "run!: failed to launch" (cons prog args)))
          ((not (zero? code))
           (error "run!: non-zero exit" code (cons prog args)))
          (else code))))

    (define (run? prog . args)
      "Syntax: (run? prog arg ...)
Library: (scm system)
Description: Returns #t when the program exits with status 0, #f otherwise.
  Useful for predicates like (run? \"test\" \"-f\" path).
Example:
  (run? \"test\" \"-f\" \"/etc/hosts\") => #t"
      (let ((code (run-program (cons prog args))))
        (and code (zero? code))))

    (define (sh prog . args)
      "Syntax: (sh prog arg ...)
Library: (scm system)
Description: Runs the program and returns its captured stdout as a string.
  Raises an error on non-zero exit. Trailing newlines are preserved.
Example:
  (sh \"date\" \"+%Y\") => \"2026\\n\""
      (let ((r (run-program/capture (cons prog args))))
        (cond
          ((not (pair? r))
           (error "sh: failed to launch" (cons prog args)))
          ((not (zero? (car r)))
           (error "sh: non-zero exit" (car r) (caddr r) (cons prog args)))
          (else (cadr r)))))

    (define (sh-lines prog . args)
      "Syntax: (sh-lines prog arg ...)
Library: (scm system)
Description: Like sh but returns stdout split into a list of lines
  (the trailing empty line from a final newline is dropped).
Example:
  (sh-lines \"ls\" \"/tmp\") => (\"file1\" \"file2\")"
      (let* ((out (apply sh prog args))
             (n (string-length out)))
        (let loop ((i 0) (start 0) (acc '()))
          (cond
            ((>= i n)
             (reverse (if (= start i) acc
                          (cons (substring out start i) acc))))
            ((char=? (string-ref out i) #\newline)
             (loop (+ i 1) (+ i 1)
                   (cons (substring out start i) acc)))
            (else (loop (+ i 1) start acc))))))

    (define (shell-quote s)
      "Syntax: (shell-quote s)
Library: (scm system)
Description: Returns s quoted such that it can be safely passed as a single
  argument to a POSIX shell (e.g. via /bin/sh -c). Wraps the string in
  single quotes and escapes any embedded single quotes.
Example:
  (shell-quote \"it's fine\") => \"'it'\\\\''s fine'\""
      (let* ((n (string-length s))
             (out (open-output-string)))
        (write-char #\' out)
        (let loop ((i 0))
          (cond
            ((>= i n) (write-char #\' out) (get-output-string out))
            (else
             (let ((c (string-ref s i)))
               (if (char=? c #\')
                   (begin (write-char #\' out) (write-char #\\ out)
                          (write-char #\' out) (write-char #\' out))
                   (write-char c out)))
             (loop (+ i 1)))))))

    (define (sleep seconds)
      "Syntax: (sleep seconds)
Library: (scm system)
Description: Pauses the current thread for the given number of seconds
  (which may be fractional). Returns an unspecified value. Uses SRFI 18
  thread-sleep! internally.
Example:
  (sleep 1.5)"
      (thread-sleep! seconds))

    (define (watch thunk . opts)
      "Syntax: (watch thunk [option ...])
Library: (scm system)
Description: Repeatedly invokes the zero-argument thunk, sleeping between
  invocations. Returns when thunk raises or when the iteration limit is
  reached. Options:
    '(interval . seconds) — seconds between calls (default 2)
    '(count . n)          — stop after n iterations (default: forever)
Example:
  (watch (lambda () (display (sh \"date\")) (newline))
         '(interval . 5) '(count . 3))"
      (let ((interval (let loop ((o opts))
                        (cond
                          ((null? o) 2)
                          ((and (pair? (car o))
                                (eq? (car (car o)) 'interval))
                           (cdr (car o)))
                          (else (loop (cdr o))))))
            (limit (let loop ((o opts))
                     (cond
                       ((null? o) #f)
                       ((and (pair? (car o))
                             (eq? (car (car o)) 'count))
                        (cdr (car o)))
                       (else (loop (cdr o)))))))
        (let iter ((i 0))
          (cond
            ((and limit (>= i limit)) #t)
            (else
             (thunk)
             (thread-sleep! interval)
             (iter (+ i 1)))))))))
