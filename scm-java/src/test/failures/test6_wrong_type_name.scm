(import (scheme base))

;; (- h 4) compiles to a fused opcode; its failure must be reported as `-`
;; at its own position, not as the `car` that ran before it.
(define (f h)
  (- h 4))

(define (g p)
  (car p)
  (f 'x))

(g '(1 . 2))
