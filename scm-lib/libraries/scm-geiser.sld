(define-library (scm geiser)
  (import (scheme base)
          (scheme read)
          (scheme write)
          (scheme eval)
          (scheme load)
          (scm module)
          (scm repl)
          (scm doc)
          (scm macro)
          (only (scm core) set-current-output-port))
  (export geiser:eval
          geiser:completions
          geiser:module-completions
          geiser:autodoc
          geiser:no-values
          geiser:newline
          geiser:load-file
          geiser:add-to-load-path
          geiser:macroexpand
          geiser:symbol-location
          geiser:module-location
          geiser:module-exports)
  (begin

    ;; ---------- helpers ----------

    (define (write-to-string form)
      (let ((p (open-output-string)))
        (write form p)
        (get-output-string p)))

    (define (str-prefix? prefix s)
      (let ((np (string-length prefix))
            (ns (string-length s)))
        (and (<= np ns)
             (let loop ((i 0))
               (cond ((= i np) #t)
                     ((char=? (string-ref prefix i) (string-ref s i))
                      (loop (+ i 1)))
                     (else #f))))))

    (define (->string x)
      (cond ((string? x) x)
            ((symbol? x) (symbol->string x))
            (else (write-to-string x))))

    (define (condition->string err)
      (cond ((error-object? err)
             (let ((msg (error-object-message err))
                   (irritants (error-object-irritants err)))
               (if (null? irritants)
                   msg
                   (string-append msg " " (write-to-string irritants)))))
            (else (write-to-string err))))

    (define (geiser-environment module)
      ;; Geiser sends the module as a library-name list, #f or '() (no module
      ;; context). With no module context evaluate in the current module (the
      ;; REPL namespace when driven by Geiser); otherwise in the given module.
      (cond ((eq? module #f) (current-module))
            ((null? module) (current-module))
            ((pair? module) module)
            (else (current-module))))

    ;; Run THUNK with the default output port redirected into a string, and
    ;; return the Geiser retort alist ((result . <printed>) (output . <stdout>)).
    ;; Errors are captured and reported as the result rather than thrown, so the
    ;; driving REPL never sees an exception for a Geiser request.
    (define (run-capturing thunk)
      (let ((out (open-output-string))
            (saved (current-output-port))
            (failed #f)
            (message #f))
        (let ((value
               (dynamic-wind
                 (lambda () (set-current-output-port out))
                 (lambda ()
                   (guard (err (#t (set! failed #t)
                                   (set! message (condition->string err))
                                   #f))
                     (thunk)))
                 (lambda () (set-current-output-port saved)))))
          (if failed
              (list (list 'result message)
                    (cons 'output
                          (string-append (get-output-string out)
                                         message
                                         (string #\newline))))
              (list (list 'result (write-to-string value))
                    (cons 'output (get-output-string out)))))))

    ;; ---------- evaluation ----------

    (define (geiser:eval module form . rest)
      "Syntax: (geiser:eval module form)
Library: (scm geiser)
Description: Geiser protocol entry point. Evaluates form in the namespace of
module (a library-name list, or #f for the REPL namespace) while capturing
default output, and returns an association list of the form
((result <printed-value>) (output . <captured-output>)) that the Geiser Emacs
frontend reads back. Evaluation errors are reported in the result instead of
being raised.
Example:
  (geiser:eval #f '(+ 1 2)) => ((result \"3\") (output . \"\"))"
      (run-capturing (lambda () (eval form (geiser-environment module)))))

    (define (geiser:load-file path . rest)
      "Syntax: (geiser:load-file path)
Library: (scm geiser)
Description: Geiser protocol entry point used when loading a file from Emacs.
Loads path while capturing output and returns the same retort alist as
geiser:eval.
Example:
  (geiser:load-file \"foo.scm\")"
      (run-capturing (lambda () (load path))))

    ;; ---------- completion ----------

    (define (geiser:completions prefix . rest)
      "Syntax: (geiser:completions prefix)
Library: (scm geiser)
Description: Geiser protocol entry point for identifier completion. Returns the
list of names visible in the current module that start with prefix.
Example:
  (geiser:completions \"ca\") => (\"caar\" \"cadr\" \"car\" \"case\" ...)"
      (repl-completions (->string prefix)))

    (define (geiser:module-completions prefix . rest)
      "Syntax: (geiser:module-completions prefix)
Library: (scm geiser)
Description: Geiser protocol entry point for module-name completion. Returns the
list of loaded module names (as written strings) starting with prefix.
Example:
  (geiser:module-completions \"(scheme\") => (\"(scheme base)\" ...)"
      (let ((p (->string prefix)))
        (let loop ((ms (modules)) (acc '()))
          (cond ((null? ms) (reverse acc))
                (else
                 (let ((name (write-to-string (car ms))))
                   (if (str-prefix? p name)
                       (loop (cdr ms) (cons name acc))
                       (loop (cdr ms) acc))))))))

    ;; ---------- autodoc ----------

    ;; Turn a signature string like "(map proc list1 list2 ...)" into the
    ;; argument structure Geiser expects:
    ;;   (id ("args" (("required" ...) ("optional" ...) ("key") ("module" #f))))
    (define (parse-arglist id sig)
      (guard (e (#t (list id '())))
        (let ((form (read (open-input-string sig))))
          (if (pair? form)
              (let loop ((args (cdr form)) (req '()) (opt '()))
                (cond ((null? args)
                       (list id (list "args"
                                      (list (cons "required" (reverse req))
                                            (cons "optional" (reverse opt))
                                            (list "key")
                                            (list "module" #f)))))
                      ((symbol? args) ; dotted rest argument
                       (list id (list "args"
                                      (list (cons "required" (reverse req))
                                            (cons "optional"
                                                  (reverse (cons "..." opt)))
                                            (list "key")
                                            (list "module" #f)))))
                      ((eq? (car args) '...)
                       (loop (cdr args) req (cons "..." opt)))
                      (else
                       (loop (cdr args) (cons (car args) req) opt))))
              (list id '())))))

    (define (operator-arglist id)
      (let ((info (repl-syntax-info id)))
        (if (or (not info) (not (pair? info)))
            (list id '())
            (let ((sig (cadr info)))
              (if (= 0 (string-length sig))
                  (list id '())
                  (parse-arglist id sig))))))

    (define (geiser:autodoc ids . rest)
      "Syntax: (geiser:autodoc ids)
Library: (scm geiser)
Description: Geiser protocol entry point for autodoc (echo-area signatures).
Given a list of operator symbols, returns their argument descriptions derived
from the documented Syntax: lines.
Example:
  (geiser:autodoc '(map))"
      (cond ((null? ids) '())
            ((not (list? ids)) (geiser:autodoc (list ids)))
            ((not (symbol? (car ids))) (geiser:autodoc (cdr ids)))
            (else (map operator-arglist ids))))

    ;; ---------- locations (jump to definition) ----------

    (define (geiser:symbol-location symbol . rest)
      "Syntax: (geiser:symbol-location symbol)
Library: (scm geiser)
Description: Geiser protocol entry point for jumping to a definition. Per-symbol
source locations are not tracked in this implementation, so this always returns
the empty list (Geiser then reports no location)."
      '())

    (define (geiser:module-location module . rest)
      "Syntax: (geiser:module-location module)
Library: (scm geiser)
Description: Geiser protocol entry point for jumping to a module definition. Not
tracked in this implementation; always returns the empty list."
      '())

    ;; ---------- misc protocol entry points ----------

    (define (geiser:macroexpand form . rest)
      "Syntax: (geiser:macroexpand form)
Library: (scm geiser)
Description: Geiser protocol entry point for macro expansion. Returns the fully
expanded form rendered as a string.
Example:
  (geiser:macroexpand '(when #t 1)) => \"(if #t (begin 1) )\""
      (write-to-string (macroexpand form)))

    (define (geiser:module-exports module . rest)
      "Syntax: (geiser:module-exports module)
Library: (scm geiser)
Description: Geiser protocol entry point for the module browser. Returns the
exported bindings of module grouped into procs/syntax/vars."
      (let ((exports (guard (e (#t '())) (%module-export-bindings module))))
        (list (list "modules")
              (cons "procs" (map (lambda (s) (list (->string s))) exports))
              (list "syntax")
              (list "vars"))))

    (define (geiser:add-to-load-path directory . rest)
      "Syntax: (geiser:add-to-load-path directory)
Library: (scm geiser)
Description: Geiser protocol entry point. Prepends directory to the module
search path."
      (module-search-path! (cons directory (module-search-path)))
      (geiser:no-values))

    (define (geiser:no-values . rest)
      "Syntax: (geiser:no-values)
Library: (scm geiser)
Description: Geiser protocol entry point representing the absence of a value.
Returns an unspecified value."
      (if #f #f))

    (define (geiser:newline . rest)
      "Syntax: (geiser:newline)
Library: (scm geiser)
Description: Geiser protocol entry point. Writes a newline to the current output
port."
      (newline))

    ))
