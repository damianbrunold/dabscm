;; for tests/rtpath.scm: found only through the run-time module-search-path
(define-library (rtpath lib)
  (import (scheme base))
  (export greeting)
  (begin (define (greeting) "found through module-search-path!")))
