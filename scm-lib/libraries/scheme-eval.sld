(define-library (scheme eval)
  (export environment eval)
  (begin
    (define eval (%primitive "eval"))
    (define environment (%primitive "environment"))))
