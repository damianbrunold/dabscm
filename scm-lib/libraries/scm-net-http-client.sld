(define-library (scm net http client)
  (import (scm core) (scheme base)
          (scm net http request)
          (scm net http response))
  (export http-get
          http-post
          http-send
          http-put
          http-delete
          http-get-json
          http-post-json)
  (begin
    (define http-get  (%primitive "http-get"))
    (define http-post (%primitive "http-post"))
    (define http-send (%primitive "http-send"))

    (define (http-put url body)
      "Syntax: (http-put url body)
Library: (scm net http client)
Description: Performs an HTTP PUT request with the given body and returns an http-response.
Example:
  (http-put \"http://example.com/item/1\" \"updated\")"
      (http-send (make-http-request "PUT" url '() body)))

    (define (http-delete url)
      "Syntax: (http-delete url)
Library: (scm net http client)
Description: Performs an HTTP DELETE request and returns an http-response.
Example:
  (http-delete \"http://example.com/item/1\")"
      (http-send (make-http-request "DELETE" url '() #f)))

    (define (http-get-json url)
      "Syntax: (http-get-json url)
Library: (scm net http client)
Description: Performs an HTTP GET request with Accept: application/json header.
  Returns an http-response.
Example:
  (http-get-json \"http://example.com/api/items\")"
      (http-get url '(("Accept" . "application/json"))))

    (define (http-post-json url body)
      "Syntax: (http-post-json url body)
Library: (scm net http client)
Description: Performs an HTTP POST with Content-Type: application/json. body should
  be a JSON string. Returns an http-response.
Example:
  (http-post-json \"http://example.com/api\" \"{\\\"x\\\":1}\")"
      (http-post url body '(("Content-Type" . "application/json")
                            ("Accept" . "application/json"))))))
