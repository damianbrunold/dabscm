(define-library (scm csv)
  (export csv-line->fields)
  (begin
    (define csv-line->fields (%primitive "csv-line->fields"))))
