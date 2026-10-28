(define-library (scm net http request)
  (import (scm core) (scheme base) (scheme char))
  (export make-http-request
          http-request-method
          http-request-url
          http-request-headers
          http-request-body
          http-request-body-bytes
          http-request-body-file
          http-request?
          http-request-header
          http-request-bearer-token)
  (begin
    (define make-http-request   (%primitive "make-http-request"))
    (define http-request-method  (%primitive "http-request-method"))
    (define http-request-url     (%primitive "http-request-url"))
    (define http-request-headers (%primitive "http-request-headers"))
    (define http-request-body    (%primitive "http-request-body"))
    (define http-request-body-bytes (%primitive "http-request-body-bytes"))
    (define http-request-body-file (%primitive "http-request-body-file"))
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
          (else (loop (cdr headers))))))

    (define (http-request-bearer-token req)
      "Syntax: (http-request-bearer-token req)
Library: (scm net http request)
Description: Returns the token of an 'Authorization: Bearer <token>' header
  in req (scheme name case-insensitive, surrounding whitespace removed), or
  #f if there is none or it is empty.
Example:
  (http-request-bearer-token req) => \"eyJhbGciOi...\""
      (let ((h (http-request-header req "Authorization")))
        (and (string? h)
             (let* ((n (string-length h))
                    (start (let loop ((i 0))
                             (if (and (< i n) (char-whitespace? (string-ref h i)))
                                 (loop (+ i 1))
                                 i))))
               (and (>= (- n start) 7)
                    (string-ci=? (substring h start (+ start 6)) "Bearer")
                    (char-whitespace? (string-ref h (+ start 6)))
                    (let* ((a (let loop ((i (+ start 7)))
                                (if (and (< i n) (char-whitespace? (string-ref h i)))
                                    (loop (+ i 1))
                                    i)))
                           (b (let loop ((j n))
                                (if (and (> j a) (char-whitespace? (string-ref h (- j 1))))
                                    (loop (- j 1))
                                    j))))
                      (and (> b a) (substring h a b))))))))
))
