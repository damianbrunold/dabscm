(import (scheme base))

;; The call stack of an error inside a non-tail let body, reached through
;; non-tail calls of globals.
(define (inner x)
  (+ 1 (let ((y (* x 2)))
         (vector-ref y 0))))   ; errors: y is a number, not a vector

(define (middle x)
  (+ 1 (inner x)))

(define (outer)
  (list (middle 5)))

(outer)
