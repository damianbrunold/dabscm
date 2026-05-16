(define-library (scheme process-context)
  (export command-line emergency-exit exit
          get-environment-variable get-environment-variables)
  (begin
    (define exit                     (%primitive "exit"))
    (define emergency-exit           exit)
    (define get-environment-variable (%primitive "get-environment-variable"))
    (define command-line             (%primitive "command-line"))
    (define get-environment-variables (%primitive "get-environment-variables"))))
