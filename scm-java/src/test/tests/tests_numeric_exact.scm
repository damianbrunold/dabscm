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

(test-end "numeric-exact")
