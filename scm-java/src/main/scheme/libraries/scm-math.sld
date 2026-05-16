(define-library (scm math)
  (import (scheme base) (scheme complex))
  (export E
          PI
          factorial
          magnitude
          nil
          sign)
  (begin
    (define E (%primitive "E"))
    (define PI (%primitive "PI"))
    (define nil (%primitive "nil"))
    
    (define (sign n)
      "Syntax: (sign n)
Library: (scm math)
Description: Returns -1 if n is negative, +1 if n is positive, or 0 if n is zero.
Example:
  (sign -5) => -1
  (sign 0)  => 0
  (sign 3)  => 1"
      (cond ((< n 0) -1)
            ((> n 0) +1)
            (else 0)))

    (define (factorial n)
      "Syntax: (factorial n)
Library: (scm math)
Description: Returns the factorial of non-negative integer n (n!). Uses tail
recursion via a named let accumulator.
Example:
  (factorial 0) => 1
  (factorial 5) => 120"
      (let fact ((i n) (a 1))
        (if (= i 0)
            a
            (fact (- i 1) (* a i)))))
))
