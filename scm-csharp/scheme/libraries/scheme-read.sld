(define-library (scheme read)
  (export read)
  (begin
    (define read (%primitive "read"))))
