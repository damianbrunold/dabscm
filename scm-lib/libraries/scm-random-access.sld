(define-library (scm random access)
  (import (scheme base))
  (export open-random-access-file
          close-random-access-file
          random-access-file?
          random-access-file-read
          random-access-file-write!
          random-access-file-size
          random-access-file-truncate!
          random-access-file-flush
          call-with-random-access-file)
  (begin
    (define open-random-access-file (%primitive "open-random-access-file"))
    (define close-random-access-file (%primitive "close-random-access-file"))
    (define random-access-file? (%primitive "random-access-file?"))
    (define random-access-file-read (%primitive "random-access-file-read"))
    (define random-access-file-write! (%primitive "random-access-file-write!"))
    (define random-access-file-size (%primitive "random-access-file-size"))
    (define random-access-file-truncate! (%primitive "random-access-file-truncate!"))
    (define random-access-file-flush (%primitive "random-access-file-flush"))

    (define (call-with-random-access-file filename mode proc)
      "Syntax: (call-with-random-access-file filename mode proc)
Library: (scm random access)
Description: Opens filename for random access in the given mode (the symbol
  read, write, or update), calls proc with the resulting handle, and closes
  the handle afterwards even if proc raises an error. Returns the result of
  proc.
Example:
  (call-with-random-access-file \"data.store\" 'read
    (lambda (f) (random-access-file-read f 0 16)))"
      (let ((f (open-random-access-file filename mode)))
        (dynamic-wind
          (lambda () #f)
          (lambda () (proc f))
          (lambda () (close-random-access-file f)))))))
