;; A program's definition of an imported name: procedures defined by the
;; program see their own definition (also when they call themselves),
;; library code keeps the library's binding, and a non-procedure
;; definition sees the imported value.
(define-library (redefine lib)
  (import (scheme base))
  (export f g h)
  (begin
    (define (f) 'library-f)
    (define (g) (f))
    (define h 10)))

(import (scheme base) (scheme write) (redefine lib))

(define (f s n) (if (= n 0) "" (string-append s (f s (- n 1)))))
(write (f "ab" 3))
(newline)
(write (g))
(newline)
(define h (+ h 1))
(write h)
(newline)
