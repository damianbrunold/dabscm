(import (scheme base))

(define (inner x)
  (car x))          ; errors: x is a number, not a pair

(define (middle x)
  (inner (* x 2)))

(define (outer)
  (middle 5))

(outer)
