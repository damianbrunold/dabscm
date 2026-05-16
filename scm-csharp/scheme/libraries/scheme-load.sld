(define-library (scheme load)
  (export load)
  (begin
    (define load (%primitive "load"))))
