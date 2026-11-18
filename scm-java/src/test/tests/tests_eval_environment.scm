(import (scheme base)
        (scheme eval)
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

(test-end "eval-environment")
