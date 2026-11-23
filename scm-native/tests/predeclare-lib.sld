;; for tests/predeclare.scm: a library that defines a name it imports, and
;; uses it before the definition
(define-library (predeclare lib)
  (import (scheme base))
  (export show own-early)
  (begin
    ;; the library's own list->string, defined below, not (scheme base)'s
    (define (show l) (list->string l))
    (define (own-early) (helper))
    (define (list->string lst) (apply string-append (map symbol->string lst)))
    (define (helper) 'own)))
