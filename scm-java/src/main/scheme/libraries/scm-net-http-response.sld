(define-library (scm net http response)
  (import (scm core) (scheme base) (scheme char))
  (export make-http-response
          http-response-status
          http-response-headers
          http-response-body
          http-response?
          http-response-header
          http-ok
          http-not-found
          http-bad-request
          http-internal-error)
  (begin
    (define make-http-response   (%primitive "make-http-response"))
    (define http-response-status  (%primitive "http-response-status"))
    (define http-response-headers (%primitive "http-response-headers"))
    (define http-response-body    (%primitive "http-response-body"))
    (define http-response?        (%primitive "http-response?"))

    (define (http-response-header resp name)
      "Syntax: (http-response-header resp name)
Library: (scm net http response)
Description: Returns the value of the named header in resp, or #f if not present.
  Header name comparison is case-insensitive.
Example:
  (http-response-header resp \"Content-Type\") => \"text/html\""
      (let loop ((headers (http-response-headers resp)))
        (cond
          ((null? headers) #f)
          ((string=? (string-downcase (car (car headers)))
                     (string-downcase name))
           (cdr (car headers)))
          (else (loop (cdr headers))))))

    (define (http-ok body)
      "Syntax: (http-ok body)
Library: (scm net http response)
Description: Creates a 200 OK HTTP response with the given body string.
Example:
  (http-ok \"Hello, world!\")"
      (make-http-response 200 '() body))

    (define (http-not-found)
      "Syntax: (http-not-found)
Library: (scm net http response)
Description: Creates a 404 Not Found HTTP response.
Example:
  (http-not-found)"
      (make-http-response 404 '() "Not Found"))

    (define (http-bad-request msg)
      "Syntax: (http-bad-request msg)
Library: (scm net http response)
Description: Creates a 400 Bad Request HTTP response with msg as the body.
Example:
  (http-bad-request \"Missing field\")"
      (make-http-response 400 '() msg))

    (define (http-internal-error msg)
      "Syntax: (http-internal-error msg)
Library: (scm net http response)
Description: Creates a 500 Internal Server Error HTTP response with msg as the body.
Example:
  (http-internal-error \"Unexpected error\")"
      (make-http-response 500 '() msg))))
