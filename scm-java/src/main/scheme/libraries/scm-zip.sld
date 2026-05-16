(define-library (scm zip)
  (import (scheme base)
          (srfi 1)
          (srfi 132))
  (export call-with-input-zip
          call-with-output-zip
          call-with-output-zip-bytevector
          call-with-output-zip-entry
          close-input-zip
          close-output-zip
          get-output-zip-bytevector
          open-input-zip-file
          open-output-zip-bytevector
          open-output-zip-file
          zip-add-binary-entry
          zip-add-stored-entry
          zip-add-text-entry
          zip-entry-names
          zip-files-equal?
          zip-read-entry-bytevector)
  (begin
    (define open-output-zip-file (%primitive "open-output-zip-file"))
    (define open-output-zip-bytevector (%primitive "open-output-zip-bytevector"))
    (define close-output-zip (%primitive "close-output-zip"))
    (define get-output-zip-bytevector (%primitive "get-output-zip-bytevector"))
    (define zip-add-binary-entry (%primitive "zip-add-binary-entry"))
    (define zip-add-stored-entry (%primitive "zip-add-stored-entry"))
    (define zip-add-text-entry (%primitive "zip-add-text-entry"))
    (define open-input-zip-file (%primitive "open-input-zip-file"))
    (define zip-entry-names (%primitive "zip-entry-names"))
    (define zip-read-entry-bytevector (%primitive "zip-read-entry-bytevector"))
    (define close-input-zip (%primitive "close-input-zip"))

    (define (call-with-input-zip filename proc)
      "Syntax: (call-with-input-zip filename proc)
Library: (scm zip)
Description: Opens an existing ZIP archive at filename, calls proc with the zip
  handle, and ensures the archive is closed when proc returns or raises an
  error. Returns the result of proc.
Example:
  (call-with-input-zip \"archive.zip\" (lambda (z) (zip-entry-names z))) => (\"file.txt\")"
      (let ((z (open-input-zip-file filename)))
        (dynamic-wind
          (lambda () #f)
          (lambda () (proc z))
          (lambda () (close-input-zip z)))))

    (define (zip-files-equal? file1 file2)
      "Syntax: (zip-files-equal? file1 file2)
Library: (scm zip)
Description: Returns #t if the two ZIP files have the same entry names and identical
  entry contents (compared as bytevectors), #f otherwise. Metadata differences such
  as version-made-by or external attributes are ignored.
Example:
  (zip-files-equal? \"a.xlsx\" \"b.xlsx\") => #t"
      (call-with-input-zip file1
        (lambda (z1)
          (call-with-input-zip file2
            (lambda (z2)
              (let ((names1 (list-sort string<? (zip-entry-names z1)))
                    (names2 (list-sort string<? (zip-entry-names z2))))
                (and (equal? names1 names2)
                     (every (lambda (name)
                                (equal? (zip-read-entry-bytevector z1 name)
                                        (zip-read-entry-bytevector z2 name)))
                              names1))))))))

    (define (call-with-output-zip filename proc)
      "Syntax: (call-with-output-zip filename proc)
Library: (scm zip)
Description: Opens a new ZIP archive at filename, calls proc with the zip
  handle, and ensures the archive is closed when proc returns or raises an
  error. Returns the result of proc.
Example:
  (call-with-output-zip \"out.zip\" (lambda (z) ...)) => unspecified"
      (let ((z (open-output-zip-file filename)))
        (dynamic-wind
          (lambda () #f)
          (lambda () (proc z))
          (lambda () (close-output-zip z)))))

    (define (call-with-output-zip-bytevector proc)
      "Syntax: (call-with-output-zip-bytevector proc)
Library: (scm zip)
Description: Creates a new in-memory ZIP archive, calls proc with the zip
  handle, closes the archive, and returns the accumulated bytes as a bytevector.
  The archive is closed even if proc raises an error.
Example:
  (call-with-output-zip-bytevector
    (lambda (z) (call-with-output-zip-entry z \"hello.txt\"
                  (lambda (p) (display \"hi\" p))))) => #u8(...)"
      (let ((z (open-output-zip-bytevector))
            (closed #f))
        (dynamic-wind
          (lambda () #f)
          (lambda ()
            (proc z)
            (close-output-zip z)
            (set! closed #t)
            (get-output-zip-bytevector z))
          (lambda ()
            (unless closed (close-output-zip z))))))

    (define (call-with-output-zip-entry zip entry-name proc . rest)
      "Syntax: (call-with-output-zip-entry zip entry-name proc [time])
Library: (scm zip)
Description: Adds a new text entry named entry-name to the ZIP archive zip,
  calls proc with the output port for that entry, and ensures the port is
  flushed when proc returns or raises an error. The optional time argument
  is a Unix timestamp (integer seconds); if omitted the current time is used.
  Returns the result of proc.
Example:
  (call-with-output-zip-entry z \"readme.txt\"
    (lambda (p) (display \"hello\" p))) => unspecified"
      (let ((p (apply zip-add-text-entry zip entry-name rest)))
        (dynamic-wind
          (lambda () #f)
          (lambda () (proc p))
          (lambda () (flush-output-port p)))))))
