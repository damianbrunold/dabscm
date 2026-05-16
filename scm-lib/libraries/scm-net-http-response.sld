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
          http-forbidden
          http-unauthorized
          http-internal-error
          http-redirect
          http-see-other
          http-permanent-redirect
          html-response
          json-response
          text-response)
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
      (make-http-response 500 '() msg))

    (define (http-forbidden . opt)
      "Syntax: (http-forbidden [msg])
Library: (scm net http response)
Description: Creates a 403 Forbidden HTTP response. msg defaults to \"Forbidden\".
Example:
  (http-forbidden)
  (http-forbidden \"Admin only\")"
      (make-http-response 403 '()
                          (if (null? opt) "Forbidden" (car opt))))

    (define (http-unauthorized . opt)
      "Syntax: (http-unauthorized [msg])
Library: (scm net http response)
Description: Creates a 401 Unauthorized HTTP response. msg defaults to \"Unauthorized\".
Example:
  (http-unauthorized)"
      (make-http-response 401 '()
                          (if (null? opt) "Unauthorized" (car opt))))

    (define (http-redirect location)
      "Syntax: (http-redirect location)
Library: (scm net http response)
Description: Creates a 302 Found HTTP response with the given Location header.
  Use for temporary redirects from GET requests.
Example:
  (http-redirect \"/login\")"
      (make-http-response 302
                          (list (cons "Location" location))
                          ""))

    (define (http-see-other location)
      "Syntax: (http-see-other location)
Library: (scm net http response)
Description: Creates a 303 See Other HTTP response with the given Location header.
  Use after a successful POST to redirect to a GET (POST/Redirect/GET pattern).
Example:
  (http-see-other \"/items/42\")"
      (make-http-response 303
                          (list (cons "Location" location))
                          ""))

    (define (http-permanent-redirect location)
      "Syntax: (http-permanent-redirect location)
Library: (scm net http response)
Description: Creates a 301 Moved Permanently HTTP response with the given Location header.
Example:
  (http-permanent-redirect \"https://example.com/new\")"
      (make-http-response 301
                          (list (cons "Location" location))
                          ""))

    (define (html-response body)
      "Syntax: (html-response body)
Library: (scm net http response)
Description: Creates a 200 OK response with Content-Type text/html; charset=utf-8.
Example:
  (html-response \"<h1>hi</h1>\")"
      (make-http-response 200
                          '(("Content-Type" . "text/html; charset=utf-8"))
                          body))

    (define (json-response body)
      "Syntax: (json-response body)
Library: (scm net http response)
Description: Creates a 200 OK response with Content-Type application/json; charset=utf-8.
  body should already be a JSON-encoded string.
Example:
  (json-response \"{\\\"ok\\\":true}\")"
      (make-http-response 200
                          '(("Content-Type" . "application/json; charset=utf-8"))
                          body))

    (define (text-response body)
      "Syntax: (text-response body)
Library: (scm net http response)
Description: Creates a 200 OK response with Content-Type text/plain; charset=utf-8.
Example:
  (text-response \"hello\")"
      (make-http-response 200
                          '(("Content-Type" . "text/plain; charset=utf-8"))
                          body))))
