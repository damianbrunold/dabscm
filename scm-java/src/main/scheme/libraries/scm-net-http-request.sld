(define-library (scm net http request)
  (import (scm core) (scheme base) (scheme char))
  (export make-http-request
          http-request-method
          http-request-url
          http-request-headers
          http-request-body
          http-request-body-bytes
          http-request?
          http-request-header)
  (begin
    (define make-http-request   (%primitive "make-http-request"))
    (define http-request-method  (%primitive "http-request-method"))
    (define http-request-url     (%primitive "http-request-url"))
    (define http-request-headers (%primitive "http-request-headers"))
    (define http-request-body    (%primitive "http-request-body"))
    (define http-request-body-bytes (%primitive "http-request-body-bytes"))
    (define http-request?        (%primitive "http-request?"))

    (define (http-request-header req name)
      "Syntax: (http-request-header req name)
Library: (scm net http request)
Description: Returns the value of the named header in req, or #f if not present.
  Header name comparison is case-insensitive.
Example:
  (http-request-header req \"Host\") => \"example.com\""
      (let loop ((headers (http-request-headers req)))
        (cond
          ((null? headers) #f)
          ((string=? (string-downcase (car (car headers)))
                     (string-downcase name))
           (cdr (car headers)))
          (else (loop (cdr headers))))))))
