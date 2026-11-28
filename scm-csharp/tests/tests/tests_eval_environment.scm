(import (scheme base)
        (scheme eval)
        (scheme file)
        (scheme load)
        (scheme repl)
        (scheme write)
        (scm fs)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "eval-environment")

;; A composite environment (more than one library) must expand the
;; libraries' macros, including macros that introduce definitions.
(define env (environment '(scheme base) '(srfi 26) '(srfi 8)))

(test-group "macros in a composite environment"
  (test-equal 3 (eval '((cut + 1 <>) 2) env))
  (test-equal 3 (eval '(receive (a b) (values 1 2) (+ a b)) env))
  (test-equal 5 (eval '(when #t 5) env))
  (test-equal 2 (eval '(let-values (((a b) (values 1 2))) b) env)))

(test-group "definitions introduced by macros"
  (eval '(define-values (p q) (values 3 4)) env)
  (test-equal 7 (eval '(+ p q) env))
  (eval '(define-record-type point (make-point x) point? (x point-x)) env)
  (test-equal 9 (eval '(point-x (make-point 9)) env))
  (test-equal #t (eval '(point? (make-point 1)) env)))

(test-group "environments stay separate"
  (let ((other (environment '(scheme base) '(srfi 8))))
    (test-error (eval 'p other))))

(define tea-price 4)

(test-group "the interaction environment of a program"
  ;; a program has no REPL module: (interaction-environment) is its own top
  ;; level (the JVM and .NET once raised "user main not available"), and
  ;; load defines there, so eval sees what a loaded file defined
  (test-equal 3 (eval '(+ 1 2) (interaction-environment)))
  (test-equal 8 (eval '(* 2 tea-price) (interaction-environment)))
  (let* ((dir (mktempdir '(prefix . "eval-env")))
         (file (join-path dir "lib.scm")))
    (call-with-output-file file
      (lambda (p) (write '(define (with-vat x) (* x 2)) p)))
    (load file)
    (test-equal 10 (eval '(with-vat 5) (interaction-environment)))
    (rm dir 'recursive)))

(test-end "eval-environment")
