(import (scheme base)
        (scheme write)
        (scheme inexact)
        (scm test))

(test-runner-factory scm-test-runner)

(test-begin "numeric-exact")

;; Integral doubles beyond 2^63 are integers (Java used to go through long).
(test-group "integer?"
  (test-equal #t (integer? 1e20))
  (test-equal #t (integer? -1e20))
  (test-equal #t (integer? 1.5e300))
  (test-equal #t (integer? 9007199254740993.0))
  (test-equal #f (integer? 0.5))
  (test-equal #f (integer? +inf.0))
  (test-equal #f (integer? +nan.0)))

;; exact returns the simplest rational that reads back as the double.
(test-group "exact"
  (test-equal 1/10 (exact 0.1))
  (test-equal -3/10 (exact -0.3))
  (test-equal 1/3 (exact (/ 1. 3)))
  (test-equal 15432/125 (exact 123.456))
  (test-equal 100000000000000000000 (exact 1e20))
  ;; tiny and subnormal doubles used to raise or return 1/9223372036854775807
  (test-equal 1/99999999999999997962 (exact 1e-20))
  (test-equal #t (< (/ 999 (expt 10 303)) (exact 1e-300) (/ 1001 (expt 10 303))))
  (test-equal #t (< (/ 999 (expt 10 313)) (exact 1e-310) (/ 1001 (expt 10 313))))
  (test-equal #t (< 0 (exact 5e-324) (/ 1 (expt 2 1073))))
  (test-equal #t (negative? (exact -1e-310)))
  ;; this one used to give 0
  (test-equal #t (< 2/100000 (exact 2.4999999999999998e-5) 3/100000)))

;; inexact of a rational is correctly rounded, also beyond the double range
;; of numerator/denominator (used to give 0.0 or +nan.0) and for bignums
;; (C# truncated).
(test-group "inexact"
  (test-equal 1.0 (inexact (/ (expt 10 400) (+ 1 (expt 10 400)))))
  (test-equal #t (= (exact 1e-310) (exact (inexact (exact 1e-310)))))
  (test-equal 1e-20 (inexact (exact 1e-20)))
  (test-equal 0.0 (inexact (/ 1 (expt 10 400))))
  (test-equal +inf.0 (inexact (/ (expt 10 400) 3)))
  (test-equal 1.1805916207174116e+21 (inexact (+ (expt 2 70) (expt 2 17) 1)))   ; rounds up
  (test-equal 1.1805916207174113e+21 (inexact (+ (expt 2 70) (expt 2 17))))     ; tie, to even
  (test-equal 1.1805916207174118e+21 (inexact (+ (expt 2 70) (* 3 (expt 2 17)))))   ; tie, to even
  (test-equal 0.3333333333333333 (+ 1/3 0.0)))

;; floor, ceiling, truncate, round: inexact stays inexact (Java returned exact
;; integers beyond the long range and raised on infinities), exact rationals
;; are rounded exactly (they went through a double).
(test-group "rounding"
  (test-equal '(+inf.0 -inf.0 +inf.0 +inf.0) (list (round +inf.0) (floor -inf.0) (ceiling +inf.0) (truncate +inf.0)))
  (test-equal #t (nan? (round +nan.0)))
  (test-equal 1e300 (round 1e300))
  (test-equal #t (inexact? (floor 1e300)))
  (test-equal '(2.0 -2.0 4.0) (list (round 2.5) (round -2.5) (round 3.5)))
  (test-equal (expt 10 20) (round (+ (expt 10 20) 1/2)))        ; tie, to even
  (test-equal (+ (expt 10 20) 2) (round (+ (expt 10 20) 3/2)))
  (test-equal (+ (expt 10 20) 1) (round (+ (expt 10 20) 2/3)))
  (test-equal (- (expt 10 20)) (floor (- 1/3 (expt 10 20))))
  (test-equal (+ (expt 10 20) 1) (ceiling (+ (expt 10 20) 1/3)))
  (test-equal (- 1 (expt 10 20)) (truncate (- 1/3 (expt 10 20))))
  (test-equal '(-3 -2 -2 -2) (list (floor -5/2) (ceiling -5/2) (truncate -5/2) (round -5/2))))

;; quotient, remainder, modulo and the floor/ family with inexact arguments
;; are computed exactly (they went through long); modulo with a zero
;; remainder and a negative divisor returned the divisor.
(test-group "integer-division"
  (test-equal 3.333333333333333e+19 (quotient 1e20 3.))
  (test-equal 1.0 (remainder 1e20 3.))
  (test-equal -2.0 (modulo 1e20 -3.))
  (test-equal 1.4285714285714286e+299 (quotient 1e300 7.))
  (test-equal -3.333333333333333e+19 (quotient -1e20 3))
  (test-equal 0 (modulo 6 -3))
  (test-equal 0 (modulo (expt 10 30) (- (expt 10 10))))
  (test-equal 0.0 (modulo 6. -3.))
  (test-equal '(-2 -1 2) (list (modulo 7 -3) (modulo -7 -3) (modulo -7 3)))
  (test-equal '(3.333333333333333e+19 1.0) (call-with-values (lambda () (floor/ 1e20 3.)) list))
  (test-equal '(3.333333333333333e+19 1.0) (call-with-values (lambda () (truncate/ 1e20 3.)) list))
  (test-equal -3.333333333333333e+19 (floor-quotient 1e20 -3.))
  (test-equal -9.600491718009862e+16 (floor-quotient 6.427145185538882e+21 -66946.))   ; rounded once
  (test-equal '(-3 1) (call-with-values (lambda () (floor/ -5 2)) list))
  (test-equal '(-3 -1) (call-with-values (lambda () (floor/ 5 -2)) list))
  (test-equal "Failed in quotient: wrong argument type"
              (guard (e ((error-object? e) (error-object-message e))) (quotient 7.5 2))))

(test-end "numeric-exact")
