;; include: the file's forms where the include stands, resolved against the
;; directory of the file with the include (a nested include too), its
;; value the last form's
(import (scheme base) (scheme write))
(define base 10)
(include "include-dir/inc-outer.scm")
(write (helper 5)) (newline)
(write (inner-helper 2)) (newline)
(define (f) (include "include-dir/inc-value.scm"))
(write (f)) (newline)
