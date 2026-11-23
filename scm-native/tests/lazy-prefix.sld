;; for tests/lazyimport.scm: a setting the program sets before importing
;; (lazy page)
(define-library (lazy prefix)
  (import (scheme base) (scheme write))
  (export set-prefix! current-prefix)
  (begin
    (display "init (lazy prefix)")
    (newline)
    (define prefix "")
    (define (set-prefix! p) (set! prefix p))
    (define (current-prefix) prefix)))
