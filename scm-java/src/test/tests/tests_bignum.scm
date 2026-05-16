(import (scheme base) (scm test) (srfi 151))

(test-runner-factory scm-test-runner)

(test-begin "bignum")

;; Overflow promotion
(test-equal 9223372036854775808 (+ 9223372036854775807 1))
(test-equal -9223372036854775809 (- -9223372036854775808 1))
(test-equal 18446744073709551614 (* 9223372036854775807 2))
(test-equal 9223372036854775808 (- -9223372036854775808))

;; Auto-demotion
(test-equal 9223372036854775807 (- (+ 9223372036854775807 1) 1))
(test-equal 0 (- 9223372036854775808 9223372036854775808))

;; Exponentiation
(test-equal 1267650600228229401496703205376 (expt 2 100))
(test-equal 18446744073709551616 (expt 2 64))
(test-equal 1/1024 (expt 2 -10))
(test-equal 1000000000000000000000000000000 (expt 10 30))
(test-equal 1 (expt 2 0))
(test-equal 1 (expt 0 0))

;; Predicates
(test-assert (integer? (expt 2 100)))
(test-assert (exact? (expt 2 100)))
(test-assert (number? (expt 2 100)))
(test-assert (real? (expt 2 100)))
(test-assert (rational? (expt 2 100)))
(test-assert (eqv? (expt 2 100) (expt 2 100)))
(test-assert (equal? (expt 2 100) (expt 2 100)))

;; Comparison
(test-assert (< (expt 2 100) (expt 2 101)))
(test-assert (= (expt 2 100) (expt 2 100)))
(test-assert (> (expt 2 100) 5))
(test-assert (< 0 (expt 2 100)))
(test-assert (>= (expt 2 100) (expt 2 100)))
(test-assert (<= (expt 2 100) (expt 2 101)))

;; Arithmetic
(test-equal (expt 2 101) (+ (expt 2 100) (expt 2 100)))
(test-equal (expt 2 100) (- (expt 2 101) (expt 2 100)))
(test-equal (expt 2 100) (* (expt 2 50) (expt 2 50)))

;; Division
(test-equal 2 (/ (expt 2 100) (expt 2 99)))
(test-equal 422550200076076467165567735125 (quotient (expt 2 100) 3))
(test-equal 1 (remainder (expt 2 100) 3))
(test-equal 1 (modulo (expt 2 100) 3))

;; Bitwise
(test-equal (expt 2 100) (arithmetic-shift 1 100))
(test-equal (expt 2 100) (bitwise-and (expt 2 100) (- (expt 2 101) 1)))
(test-equal (+ (expt 2 100) (expt 2 50)) (bitwise-ior (expt 2 100) (expt 2 50)))
(test-equal 0 (bitwise-xor (expt 2 100) (expt 2 100)))
(test-equal (expt 2 50) (arithmetic-shift (expt 2 100) -50))

;; Display
(test-equal "1267650600228229401496703205376" (number->string (expt 2 100)))
(test-equal "10000000000000000" (number->string (expt 2 64) 16))

;; Inexact conversion
(test-equal 1.2676506002282294e30 (inexact (expt 2 100)))

;; Factorial
(test-group "factorial"
  (define (fact n) (if (= n 0) 1 (* n (fact (- n 1)))))
  (test-equal 2432902008176640000 (fact 20))
  (test-assert (integer? (fact 50)))
  (test-assert (exact? (fact 50)))
  (test-assert (> (fact 50) (fact 49))))

;; Parsing big literals
(test-equal 99999999999999999999999 (string->number "99999999999999999999999"))
(test-equal 18446744073709551616 (string->number "18446744073709551616"))
(test-equal 99999999999999999999999 99999999999999999999999)

;; Rational with big numerator/denominator
(test-assert (eqv? 1/3 1/3))
(test-assert (equal? 1/1024 1/1024))
(test-assert (exact? (/ (expt 2 100) (expt 3 50))))
(test-assert (rational? (/ (expt 2 100) (expt 3 50))))

(test-end "bignum")
