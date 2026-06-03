(define-library (scm io)
  (import (scheme base)
          (scheme file))
  (export call-with-input-string
          call-with-output-bytevector
          call-with-output-string
          field-sep
          file->lines
          file->string
          flush
          format
          line-sep
          port-position
          read-chars
          read-file-lines
          read-file-string
          with-input-from-string)
  (begin
    (define format (%primitive "format"))
    (define flush (%primitive "flush-output-port"))
    (define read-chars (%primitive "read-chars"))
    (define port-position (%primitive "port-position"))
    (define field-sep (%primitive "field-sep"))
    (define line-sep (%primitive "line-sep"))


    (define (read-file-string path . opts)
      "Syntax: (read-file-string path option ...)
Library: (scm io)
Description: Reads the entire contents of the file at path and returns it as a
  string. Each option is passed on to open-input-file; supported options are
  an encoding (such as 'utf-8, 'latin-1 or 'utf-16) and the symbol 'deflate to
  transparently inflate deflate-compressed input. If the file cannot be opened
  or read (for example it does not exist), an error is raised. Use file->string
  for a variant that returns #f on error instead. The input port is always
  closed.
Example:
  (read-file-string \"hello.txt\") => \"hello\\nworld\\n\"
  (read-file-string \"data.txt\" 'latin-1) => \"...\""
      (let ((p (apply open-input-file path opts)))
        (dynamic-wind
          (lambda () #f)
          (lambda ()
            (let ((out (open-output-string)))
              (let loop ()
                (let ((chunk (read-chars 65536 p)))
                  (if (eof-object? chunk)
                      (get-output-string out)
                      (begin (write-string chunk out) (loop)))))))
          (lambda () (close-input-port p)))))

    (define (read-file-lines path . opts)
      "Syntax: (read-file-lines path option ...)
Library: (scm io)
Description: Reads the entire contents of the file at path and returns it as a
  list of strings, one per line, with line terminators removed. Each option is
  passed on to open-input-file; supported options are an encoding (such as
  'utf-8, 'latin-1 or 'utf-16) and the symbol 'deflate to transparently inflate
  deflate-compressed input. If the file cannot be opened or read (for example
  it does not exist), an error is raised. Use file->lines for a variant that
  returns #f on error instead. The input port is always closed.
Example:
  (read-file-lines \"hello.txt\") => (\"hello\" \"world\")
  (read-file-lines \"data.txt\" 'latin-1) => (\"...\")"
      (let ((p (apply open-input-file path opts)))
        (dynamic-wind
          (lambda () #f)
          (lambda ()
            (let loop ((acc '()))
              (let ((l (read-line p)))
                (if (eof-object? l)
                    (reverse acc)
                    (loop (cons l acc))))))
          (lambda () (close-input-port p)))))

    (define (file->string path . opts)
      "Syntax: (file->string path option ...)
Library: (scm io)
Description: Like read-file-string, but returns #f if the file cannot be opened
  or read (for example it does not exist) instead of raising an error. Each
  option is passed on to open-input-file; supported options are an encoding
  (such as 'utf-8, 'latin-1 or 'utf-16) and the symbol 'deflate to transparently
  inflate deflate-compressed input. The input port is always closed.
Example:
  (file->string \"hello.txt\") => \"hello\\nworld\\n\"
  (file->string \"data.txt\" 'latin-1) => \"...\"
  (file->string \"missing.txt\") => #f"
      (guard (e (#t #f))
        (apply read-file-string path opts)))

    (define (file->lines path . opts)
      "Syntax: (file->lines path option ...)
Library: (scm io)
Description: Like read-file-lines, but returns #f if the file cannot be opened
  or read (for example it does not exist) instead of raising an error. Each
  option is passed on to open-input-file; supported options are an encoding
  (such as 'utf-8, 'latin-1 or 'utf-16) and the symbol 'deflate to transparently
  inflate deflate-compressed input. The input port is always closed.
Example:
  (file->lines \"hello.txt\") => (\"hello\" \"world\")
  (file->lines \"data.txt\" 'latin-1) => (\"...\")
  (file->lines \"missing.txt\") => #f"
      (guard (e (#t #f))
        (apply read-file-lines path opts)))

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
