(define-library (scheme write)
  (export display newline write write-shared write-simple)
  (begin
    (define write (%primitive "write"))
    (define display (%primitive "display"))
    (define newline (%primitive "newline"))
    (define write-simple (%primitive "write-simple"))
    (define write-shared (%primitive "write-shared"))))
