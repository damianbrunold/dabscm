;; (vector-ref v k default): the default for k out of range, as on the JVM
;; (splg's input readers use it for optional trailing fields)
(import (scheme base) (scheme write))
(define v (vector 'a 'b 'c))
(write (list (vector-ref v 1) (vector-ref v 1 'none) (vector-ref v 5 'none)
             (vector-ref v -1 "") (let ((f (lambda (k) (vector-ref v k #f)))) (f 3))))
(newline)
