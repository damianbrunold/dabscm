(define-library (scm io)
  (import (scheme base))
  (export call-with-input-string
          call-with-output-bytevector
          call-with-output-string
          field-sep
          flush
          format
          line-sep
          port-position
          read-chars
          with-input-from-string)
  (begin
    (define format (%primitive "format"))
    (define flush (%primitive "flush-output-port"))
    (define read-chars (%primitive "read-chars"))
    (define port-position (%primitive "port-position"))
    (define field-sep (%primitive "field-sep"))
    (define line-sep (%primitive "line-sep"))


    (define (call-with-output-bytevector proc)
      "Syntax: (call-with-output-bytevector proc)
Library: (scm io)
Description: Calls proc with a fresh bytevector output port, then returns the
  accumulated output as a bytevector. The port is closed after proc returns,
  even if proc raises an error.
Example:
  (call-with-output-bytevector (lambda (p) (write-bytevector #u8(1 2 3) p)))
  => #u8(1 2 3)"
      (let ((p (open-output-bytevector)))
        (dynamic-wind
          (lambda () #f)
          (lambda () (proc p) (get-output-bytevector p))
          (lambda () (close-output-port p)))))

    (define (call-with-output-string proc)
      "Syntax: (call-with-output-string proc)
Library: (scm io)
Description: Calls proc with a fresh string output port, then returns the
  accumulated output as a string. The port is closed after proc returns,
  even if proc raises an error.
Example:
  (call-with-output-string (lambda (p) (display \"hello\" p) (display \" world\" p)))
  => \"hello world\""
      (let ((p (open-output-string)))
        (dynamic-wind
          (lambda () #f)
          (lambda () (proc p) (get-output-string p))
          (lambda () (close-output-port p)))))

    (define (call-with-input-string str proc)
      "Syntax: (call-with-input-string str proc)
Library: (scm io)
Description: Opens a string input port on str and calls proc with it,
  returning the result of proc. The port is closed after proc returns,
  even if proc raises an error.
Example:
  (call-with-input-string \"42\" read) => 42"
      (let ((p (open-input-string str)))
        (dynamic-wind
          (lambda () #f)
          (lambda () (proc p))
          (lambda () (close-input-port p)))))

    (define (with-input-from-string str thunk)
      "Syntax: (with-input-from-string str thunk)
Library: (scm io)
Description: Temporarily redirects the current input port to a string input
  port opened on str, calls thunk with no arguments, then restores the
  original current input port and closes the string port. Returns the result
  of thunk. The port is restored even if thunk raises an error.
Example:
  (with-input-from-string \"hello\" read) => hello"
      (let ((p (open-input-string str))
            (orig (current-input-port)))
        (dynamic-wind
          (lambda () (set-current-input-port p))
          (lambda () (thunk))
          (lambda ()
            (set-current-input-port orig)
            (close-input-port p)))))))
