(import (scheme base))

; Define a library inline that has a bad import
(define-library (test badlib)
  (import (scheme base))
  (import (nonexistent dependency))
  (export greet)
  (begin (define (greet x) x)))

(import (test badlib))
