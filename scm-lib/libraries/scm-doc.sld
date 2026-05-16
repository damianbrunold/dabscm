(define-library (scm doc)
  (export doc procedure-doc)
  (begin
    (define doc (%primitive "doc"))
    (define procedure-doc (%primitive "procedure-doc"))))
