(define-library (scheme case-lambda)
  (import (scm core))
  (export case-lambda)
  (begin
    (define symbol? (%primitive "symbol?"))
    (define null? (%primitive "null?"))
    (define pair? (%primitive "pair?"))
    (define = (%primitive "="))
    (define cdr (%primitive "cdr"))
    (define - (%primitive "-"))
    (define error (%primitive "error"))
    (define apply (%primitive "apply"))
    (define car (%primitive "car"))
    (define (list . x) x)

    ;; Check if a formals spec matches nargs
    (define (%case-lambda-match? formals nargs)
      "Syntax: (%case-lambda-match? formals nargs)
Library: (scheme case-lambda)
Description: Internal helper that returns #t if the given formals
specification is compatible with nargs actual arguments. A symbol formals
accepts any number of arguments (rest parameter); a null formals requires
exactly zero arguments; a pair formals requires at least as many arguments
as there are elements in the proper or improper list.
Example:
  (%case-lambda-match? '(a b) 2) => #t
  (%case-lambda-match? '(a b) 3) => #f
  (%case-lambda-match? 'rest 5)  => #t"
      (cond
        ((symbol? formals) #t)
        ((null? formals) (= nargs 0))
        ((pair? formals)
         (if (= nargs 0) #f (%case-lambda-match? (cdr formals) (- nargs 1))))
        (else #t)))

    ;; Dispatch to matching clause
    (define (%case-lambda-dispatch args nargs procs fmls-list)
      "Syntax: (%case-lambda-dispatch args nargs procs fmls-list)
Library: (scheme case-lambda)
Description: Internal dispatch helper for case-lambda. Iterates over the
parallel lists procs and fmls-list, calling the first procedure whose
formals specification matches nargs. Raises an error if no clause matches.
Example:
  (%case-lambda-dispatch '(1 2) 2
    (list (lambda (a b) (+ a b)))
    '((a b))) => 3"
      (if (null? procs)
          (error "case-lambda: no matching clause" nargs)
          (if (%case-lambda-match? (car fmls-list) nargs)
              (apply (car procs) args)
              (%case-lambda-dispatch args nargs (cdr procs) (cdr fmls-list)))))

    (define-syntax case-lambda
      "Syntax: (case-lambda (formals body ...) ...)
Library: (scheme case-lambda)
Description: Returns a procedure that, when called, selects the first clause
whose formals specification is compatible with the number of actual arguments
and evaluates the body expressions of that clause in a new environment where
the formals are bound to the actual arguments. Raises an error if no clause
matches. This allows a single procedure to accept different numbers of
arguments.
Example:
  (define f
    (case-lambda
      ((x)   (* x x))
      ((x y) (+ x y))))
  (f 5)   => 25
  (f 3 4) => 7"
      (syntax-rules ()
        ((case-lambda (formals body ...) ...)
         (lambda args
           (let ((nargs (length args)))
             (%case-lambda-dispatch args nargs
               (list (lambda formals body ...) ...)
               (list 'formals ...)))))))))
