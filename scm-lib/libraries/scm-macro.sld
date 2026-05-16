(define-library (scm macro)
  (import (scm core) (scheme base) (scheme cxr) (scheme write)
          (only (scm compile) gensym)
          (only (scm io) call-with-output-string))
  (export define-if-not-bound
          macroexpand
          pretty-print)
  (begin
    (define bound? (%primitive "bound?"))

    (define-syntax define-if-not-bound
      "Syntax: (define-if-not-bound name value)
Library: (scm macro)
Description: Defines name to value only if name is not already bound in
the current module. Useful for conditional initialization.
Example:
  (define-if-not-bound my-var 42)"
      (syntax-rules ()
        ((define-if-not-bound name value)
         (if (not (bound? 'name))
             (define name value)))))

    ;; macroexpand is a C# primitive using the Dybvig Expander.
    (define macroexpand (%primitive "macroexpand"))

    (define pp-line-width 79)

    (define pp-indent2-forms
      '(begin define define-syntax define-record-type
        lambda let let* letrec letrec* let-values let*-values
        when unless do guard define-library))

    (define (pp-write-to-string expr)
      (call-with-output-string (lambda (p) (write expr p))))

    (define (pp-spaces n port)
      (let loop ((i 0))
        (when (< i n) (write-char #\space port) (loop (+ i 1)))))

    (define (pp-expr expr indent port)
      (if (not (pair? expr))
          (write expr port)
          (let* ((s   (pp-write-to-string expr))
                 (len (string-length s)))
            (if (<= (+ indent len) pp-line-width)
                (display s port)
                (pp-list expr indent port)))))

    (define (pp-list expr indent port)
      (write-char #\( port)
      (let* ((head      (car expr))
             (tail      (cdr expr))
             (head-str  (pp-write-to-string head))
             (head-len  (string-length head-str))
             (indent2?  (and (symbol? head) (memq head pp-indent2-forms)))
             (first-col (+ indent 1 head-len 1))
             (body-ind  (if indent2? (+ indent 2) first-col)))
        (display head-str port)
        (cond
          ((null? tail)
           (write-char #\) port))
          ((pair? tail)
           (write-char #\space port)
           (pp-expr (car tail) first-col port)
           (let loop ((items (cdr tail)))
             (cond
               ((null? items)
                (write-char #\) port))
               ((pair? items)
                (newline port)
                (pp-spaces body-ind port)
                (pp-expr (car items) body-ind port)
                (loop (cdr items)))
               (else
                (display " . " port)
                (write items port)
                (write-char #\) port)))))
          (else
           (display " . " port)
           (write tail port)
           (write-char #\) port)))))

    (define (pretty-print expr . args)
      "Syntax: (pretty-print expr port?)
Library: (scm macro)
Description: Prints expr in a human-readable indented format to port
(default: current-output-port). Follows a line-width of 79 characters.
Example:
  (pretty-print '(define (f x) (+ x 1)))"
      (let ((port (if (null? args) (current-output-port) (car args))))
        (pp-expr expr 0 port)
        (newline port)))))
