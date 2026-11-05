(define-library (scheme process-context)
  (export command-line
          emergency-exit
          exit
          get-environment-variable
          get-environment-variables
          set-exit-code!)
  (begin
    (define exit (%primitive "exit"))
    (define set-exit-code! (%primitive "set-exit-code!"))
    (define emergency-exit exit)
    (define get-environment-variable (%primitive "get-environment-variable"))
    (define command-line (%primitive "command-line"))
    (define get-environment-variables
      (%primitive "get-environment-variables"))))
