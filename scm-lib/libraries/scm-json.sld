(define-library (scm json)
  (export close-json
          json-attribute
          json-next-object
          open-json-file
          open-json-string)
  (begin
    (define close-json (%primitive "close-json"))
    (define json-attribute (%primitive "json-attribute"))
    (define json-next-object (%primitive "json-next-object"))
    (define open-json-file (%primitive "open-json-file"))
    (define open-json-string (%primitive "open-json-string"))))
