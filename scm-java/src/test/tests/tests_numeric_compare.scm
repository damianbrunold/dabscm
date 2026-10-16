(import (scheme base)
        (scheme write)
        (scm test))

(test-runner-factory scm-test-runner)

;; The error message of thunk's condition, or 'no-error.
(define (error-message thunk)
  (guard (e ((error-object? e) (error-object-message e)))
    (thunk)
    'no-error))

(define (error-irritants thunk)
  (guard (e ((error-object? e) (error-object-irritants e)))
    (thunk)
    'no-error))

;; Through a procedure value, so the primitive is called, not the intrinsic.
(define (via-primitive op . args) (apply op args))

(define big (/ (+ (expt 10 20) 1) (expt 10 20)))   ; 1 + 10^-20, exact

(test-begin "numeric-compare")

;; Non-numbers used to compare as 0 instead of raising.
(test-group "non-numbers-raise"
  (test-equal "Failed in <: wrong argument type" (error-message (lambda () (< 'a 2))))
  (test-equal "Failed in <: wrong argument type" (error-message (lambda () (< 2 'a))))
  (test-equal "Failed in =: wrong argument type" (error-message (lambda () (= 'a 0))))
  (test-equal "Failed in =: wrong argument type" (error-message (lambda () (= 0 #f))))
  (test-equal "Failed in >: wrong argument type" (error-message (lambda () (> 1 #\a))))
  (test-equal "Failed in <=: wrong argument type" (error-message (lambda () (<= '() 0 0))))
  (test-equal "Failed in >=: wrong argument type" (error-message (lambda () (>= 1.5 "x"))))
  (test-equal "Failed in <: wrong argument type" (error-message (lambda () (< 1 2 'a))))
  (test-equal "Failed in =: wrong argument type" (error-message (lambda () (= 1/2 'a))))
  (test-equal "Failed in =: wrong argument type" (error-message (lambda () (= +nan.0 'a))))
  (test-equal "Failed in <: wrong argument type" (error-message (lambda () (via-primitive < 'a 1))))
  (test-equal "Failed in =: wrong argument type" (error-message (lambda () (via-primitive = 0 'a))))
  (test-equal '(a) (error-irritants (lambda () (< 'a 2))))
  (test-equal '(a) (error-irritants (lambda () (via-primitive < 'a 1))))
  (test-equal "Failed in =: wrong argument type" (error-message (lambda () (zero? 'a))))
  (test-equal "Failed in >: wrong argument type" (error-message (lambda () (max 'a 1)))))

;; Exact operands used to be compared as doubles when one was a rational.
(test-group "exact-rationals"
  (test-equal #f (= big 1))
  (test-equal #t (< 1 big))
  (test-equal #t (> big 1))
  (test-equal #f (<= big 1))
  (test-equal #f (via-primitive = big 1))
  (test-equal #t (via-primitive < 1 big))
  (test-equal #f (= 1/3 (/ 333333333333333333 1000000000000000000)))
  (test-equal #t (< (/ 333333333333333333 1000000000000000000) 1/3))
  (test-equal #t (< 1/3 1/2 2/3))
  (test-equal #t (= 1/2 2/4)))

;; An inexact operand is compared by its exact value.
(test-group "mixed-exact-inexact"
  (test-equal #f (= 1/3 0.3333333333333333))
  (test-equal #t (< 0.3333333333333333 1/3))
  (test-equal #t (> 1/3 0.3333333333333333))
  (test-equal #f (= big 1.0))
  (test-equal #t (< 1.0 big))
  (test-equal #t (= 0.5 1/2))
  (test-equal #t (= 1/2 0.5))
  (test-equal #t (<= 1/2 0.5 1))
  (test-equal #t (= 5e-324 (/ 1 (expt 2 1074))))      ; smallest subnormal, exactly
  (test-equal #t (< 1e-310 (/ 1 (expt 10 310))))
  (test-equal #t (< 1/2 +inf.0))
  (test-equal #t (> 1/2 -inf.0))
  (test-equal #f (= 1/2 +nan.0))
  (test-equal #f (< 1/2 +nan.0)))

;; Every ordering comparison with NaN is false (<= and >= used to be #t
;; through the intrinsics, < and > through the primitives).
(test-group "nan"
  (test-equal '(#f #f #f #f #f) (list (< +nan.0 1) (> +nan.0 1) (<= +nan.0 1) (>= +nan.0 1) (= +nan.0 1)))
  (test-equal '(#f #f #f #f #f) (list (< 1.0 +nan.0) (> 1.0 +nan.0) (<= 1.0 +nan.0) (>= 1.0 +nan.0) (= 1.0 +nan.0)))
  (test-equal '(#f #f #f #f) (list (< 1/2 +nan.0) (> +nan.0 1/2) (<= +nan.0 1/2) (>= 1/2 +nan.0)))
  (test-equal '(#f #f #f #f #f) (list (<= +nan.0 +nan.0) (>= +nan.0 +nan.0) (= +nan.0 +nan.0) (< +nan.0 +inf.0) (> +inf.0 +nan.0)))
  (test-equal '(#f #f #f #f) (list (via-primitive < 1.0 +nan.0) (via-primitive > +nan.0 1.0)
                                  (via-primitive <= +nan.0 1) (via-primitive >= 1/2 +nan.0)))
  (test-equal #f (<= 0 +nan.0 1))
  (test-equal #f (via-primitive < 0 1 +nan.0)))

(test-end "numeric-compare")
