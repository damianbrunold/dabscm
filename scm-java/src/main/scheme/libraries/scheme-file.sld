(define-library (scheme file)
  (import (scm core) (scheme base))
  (export call-with-input-file
          call-with-output-file
          close-input-port
          close-output-port
          delete-file
          file-exists?
          open-binary-input-file
          open-binary-output-file
          open-input-file
          open-output-file
          with-input-from-file
          with-output-to-file)
  (begin
    (define open-input-file (%primitive "open-input-file"))
    (define open-output-file (%primitive "open-output-file"))
    (define open-binary-input-file (%primitive "open-binary-input-file"))
    (define open-binary-output-file (%primitive "open-binary-output-file"))
    (define close-input-port (%primitive "close-input-port"))
    (define close-output-port (%primitive "close-output-port"))
    (define file-exists? (%primitive "file-exists?"))
    (define delete-file (%primitive "delete-file"))

    (define (call-with-input-file filename proc)
      "Syntax: (call-with-input-file filename proc)
Library: (scheme file)
Description: Opens the file named by filename for input and calls proc with the resulting input port
  as its sole argument. When proc returns, the port is closed automatically via dynamic-wind, even
  if a non-local exit occurs. Returns the value(s) returned by proc. filename may also be a list
  whose car is the filename and whose remaining elements are options passed to open-input-file.
Example:
  (call-with-input-file \"data.txt\"
    (lambda (port) (read port))) => <first datum from file>"
      (let ((p (if (pair? filename)
                   (apply open-input-file filename)
                   (open-input-file filename))))
        (dynamic-wind
          (lambda () #f)
          (lambda () (proc p))
          (lambda () (close-input-port p)))))

    (define (with-input-from-file filename thunk)
      "Syntax: (with-input-from-file filename thunk)
Library: (scheme file)
Description: Opens the file named by filename for input, makes it the current input port, and calls
  thunk with no arguments. When thunk returns, the original current input port is restored and the
  opened port is closed, both managed via dynamic-wind so they occur even on non-local exits.
  Returns the value(s) returned by thunk. filename may also be a list whose car is the filename
  and whose remaining elements are options passed to open-input-file.
Example:
  (with-input-from-file \"data.txt\"
    (lambda () (read))) => <first datum from file>"
      (let ((p (if (pair? filename)
                   (apply open-input-file filename)
                   (open-input-file filename)))
            (orig (current-input-port)))
        (dynamic-wind
          (lambda () (set-current-input-port p))
          (lambda () (thunk))
          (lambda ()
            (set-current-input-port orig)
            (close-input-port p)))))

    (define (call-with-output-file filename proc)
      "Syntax: (call-with-output-file filename proc)
Library: (scheme file)
Description: Opens the file named by filename for output and calls proc with the resulting output
  port as its sole argument. When proc returns, the port is closed automatically via dynamic-wind,
  even if a non-local exit occurs. Returns the value(s) returned by proc. filename may also be a
  list whose car is the filename and whose remaining elements are options passed to open-output-file.
Example:
  (call-with-output-file \"out.txt\"
    (lambda (port) (write 42 port))) => <unspecified>"
      (let ((p (if (pair? filename)
                   (apply open-output-file filename)
                   (open-output-file filename))))
        (dynamic-wind
          (lambda () #f)
          (lambda () (proc p))
          (lambda () (close-output-port p)))))

    (define (with-output-to-file filename thunk)
      "Syntax: (with-output-to-file filename thunk)
Library: (scheme file)
Description: Opens the file named by filename for output, makes it the current output port, and
  calls thunk with no arguments. When thunk returns, the original current output port is restored
  and the opened port is closed, both managed via dynamic-wind so they occur even on non-local
  exits. Returns the value(s) returned by thunk. filename may also be a list whose car is the
  filename and whose remaining elements are options passed to open-output-file.
Example:
  (with-output-to-file \"out.txt\"
    (lambda () (display \"hello\"))) => <unspecified>"
      (let ((p (if (pair? filename)
                   (apply open-output-file filename)
                   (open-output-file filename)))
            (orig (current-output-port)))
        (dynamic-wind
          (lambda () (set-current-output-port p))
          (lambda () (thunk))
          (lambda ()
            (set-current-output-port orig)
            (close-output-port p)))))))
