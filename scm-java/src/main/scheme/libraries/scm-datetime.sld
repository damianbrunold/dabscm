(define-library (scm datetime)
  (export string->date-days
          string->date-seconds
          timestamp
          timestamp->string)
  (begin
    (define string->date-days (%primitive "string->date-days"))
    (define string->date-seconds (%primitive "string->date-seconds"))
    (define timestamp (%primitive "timestamp"))
    (define timestamp->string (%primitive "timestamp->string"))))
