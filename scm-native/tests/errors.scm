(import (scheme base) (scheme write))
;; output before an error must appear; the error ends the program with exit code 1
(write (list 1 2 3))
(newline)
(define (f x) (car x))
(f '())
(display "not reached")
