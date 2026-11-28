---
title: (scm net http client): HTTP requests
part: libraries
order: 1026
libraries: (scm net http client) (scm net http request) (scm net http response)
summary: GET, POST, PUT and DELETE, JSON APIs, headers and bearer tokens, text and binary bodies, timeouts and errors, redirects, a small API client with retries; tested against a local server.
---
# (scm net http client): HTTP requests

`(scm net http client)` sends HTTP and HTTPS requests and returns the
response as a value with a status, headers and a body. The examples here
talk to a small server started on this machine, so that they run without
the internet; the [server tutorial](scm-http-server.md) explains that part.

```scheme
(import (scheme base) (scheme write) (srfi 18) (scm json simple)
        (scm net http request) (scm net http response) (scm net http route)
        (scm net http server) (scm net http client))

;; a server that describes each request it receives, as JSON
(define (describe req params)
  (json-response
   (json->string
    `(("method" . ,(http-request-method req))
      ("url" . ,(http-request-url req))
      ("type" . ,(or (http-request-header req "Content-Type") 'null))
      ("token" . ,(or (http-request-bearer-token req) 'null))
      ("body" . ,(or (http-request-body req) 'null))))))

(define r (make-router))
(for-each (lambda (m) (router-add! r m "/echo" describe)) '("GET" "POST" "PUT" "PATCH" "DELETE"))
(router-add! r "GET" "/old-menu" (lambda (req p) (http-permanent-redirect "/menu")))
(router-add! r "GET" "/menu" (lambda (req p) (text-response "Sencha, Assam, Rooibos")))
(router-add! r "GET" "/logo.png" (lambda (req p) (make-http-response 200 '(("Content-Type" . "image/png"))
                                                                      (bytevector 137 80 78 71))))
(router-add! r "GET" "/slow" (lambda (req p) (thread-sleep! 3) (text-response "finally")))

(define server (start-app-with-router r 18902 8 "127.0.0.1"))
(define base "http://127.0.0.1:18902")
(define (at path) (string-append base path))
```

## GET

```scheme
(define resp (http-get (at "/menu")))
(http-response-status resp)                 ;; => 200
(http-response-body resp)                   ;; => "Sencha, Assam, Rooibos"
(http-response-header resp "Content-Type")  ;; => "text/plain; charset=utf-8"
(http-response-status (http-get (at "/coffee"))) ;; => 404
```

A 404 or 500 is a normal response, not an error: check the status.
`http-response-header` finds a header whatever its case; the names in
`http-response-headers` are lower case on some implementations and as
sent on others, so look headers up rather than comparing the alist.

## Sending data

`http-post` and `http-put` take a body; an optional alist adds headers:

```scheme
(define (echo resp) (json-parse (http-response-body resp)))

(json-ref (echo (http-post (at "/echo") "name,kg\nSencha,2\n" '(("Content-Type" . "text/csv")))) "type")
;; => "text/csv"
(json-ref (echo (http-put (at "/echo") "new price list")) "method") ;; => "PUT"
(json-ref (echo (http-delete (at "/echo"))) "method") ;; => "DELETE"
```

For JSON APIs, `http-post-json` sets the content type and `http-get-json`
asks for JSON with `Accept`. The body is a JSON string, so build it with
`json->string` from `(scm json simple)` and parse the answer with
`json-parse`:

```scheme
(define order `(("tea" . "Sencha") ("kg" . 2)))
(define answer (echo (http-post-json (at "/echo") (json->string order))))
(json-ref answer "type")                    ;; => "application/json"
(json-parse (json-ref answer "body"))       ;; => (("tea" . "Sencha") ("kg" . 2))
```

## Any request

`http-send` sends a request built with `make-http-request`: any method,
headers and body, plus a timeout. API tokens go in an `Authorization`
header:

```scheme
(define patch
  (make-http-request "PATCH" (at "/echo")
                     '(("Authorization" . "Bearer s3cr3t") ("Content-Type" . "application/json"))
                     "{\"kg\": 3}"))
(define seen (echo (http-send patch)))
(list (json-ref seen "method") (json-ref seen "token")) ;; => ("PATCH" "s3cr3t")
```

A string body is sent as UTF-8, a bytevector as it is.

## Binary bodies

Text responses (`text/*`, JSON, XML, anything with a `charset`) come back
as strings, everything else as bytevectors.
`http-get-bytevector` always gives the bytes, for downloads:

```scheme
(http-response-body (http-get (at "/logo.png"))) ;; => #u8(137 80 78 71)
(http-response-body (http-get-bytevector (at "/menu")))
;; => #u8(83 101 110 99 104 97 44 32 65 115 115 97 109 44 32 82 111 111 105 98 111 115)
```

## Redirects

Redirects are followed, and the final response is returned. To see the
redirect itself, pass `#f` for following redirects after the timeout:

```scheme
(http-response-body (http-get (at "/old-menu"))) ;; => "Sencha, Assam, Rooibos"

(define moved (http-send (make-http-request "GET" (at "/old-menu") '() #f 30 #f)))
(http-response-status moved)                ;; => 301
(http-response-header moved "Location")     ;; => "/menu"
```

That is how a client sees the `Set-Cookie` of a login that redirects.
A redirect from HTTPS to plain HTTP is never followed.

## Timeouts and errors

Requests wait up to 600 seconds by default; the GET procedures take a
timeout after the headers, `make-http-request` before the redirect flag.
A timeout, a refused connection or an unknown host raises an error:

```scheme
(http-get (at "/slow") '() 1)              ;; => error
(server-stop server)
(http-get (at "/menu"))                     ;; => error
```

The messages name the procedure and the cause, but their wording differs
between the implementations, so a program should not parse them.

## Example: an API client with retries

A client for a service that sometimes fails: retry server errors and
network errors a few times, with a growing pause, but not client errors
like 404, which would only fail again:

```scheme
(define (with-retries attempts thunk)
  (let loop ((n 1) (pause 0.05))
    (let ((resp (guard (e ((and (error-object? e) (< n attempts)) #f))
                  (thunk))))
      (cond ((and resp (< (http-response-status resp) 500)) resp)
            ((< n attempts) (thread-sleep! pause) (loop (+ n 1) (* 2 pause)))
            (else resp)))))

;; a flaky service: the first two calls fail with 503
(define calls 0)
(define flaky (make-router))
(router-add! flaky "GET" "/stock/:tea"
  (lambda (req params)
    (set! calls (+ calls 1))
    (if (<= calls 2)
        (make-http-response 503 '() "busy")
        (json-response (json->string `(("tea" . ,(params-ref params "tea")) ("kg" . 40)))))))
(define server2 (start-app-with-router flaky 18903 4 "127.0.0.1"))

(define (stock tea)
  (let ((resp (with-retries 4 (lambda () (http-get-json (string-append "http://127.0.0.1:18903/stock/" tea))))))
    (and (= (http-response-status resp) 200)
         (json-ref (json-parse (http-response-body resp)) "kg"))))

(stock "Sencha")                            ;; => 40
calls                                       ;; => 3
(server-stop server2)
```

Only retry requests that may safely run twice: a GET, or a POST the
service deduplicates (for example by an idempotency key header).

## HTTPS

HTTPS URLs work the same way. Server certificates are checked against
the system's trusted certificates; the reference page explains which
stores each implementation reads (including the Windows store and
corporate CAs under WSL), and the `SCM_TLS_DEBUG` and `SCM_TLS_INSECURE`
environment variables for diagnosing certificate trouble.

```scheme no-test
(define status (http-get-json "https://api.example.com/v1/status"))
(json-ref (json-parse (http-response-body status)) "state")
```

## Where next

- [HTTP servers](scm-http-server.md), [JSON](scm-json.md),
  [WebSockets](scm-websocket.md) for two-way connections.
- `(scm net-remote)`'s `curl` runs the curl program, for options this
  library lacks (client certificates, proxies).
- Reference: `(scm net http client)`, `(scm net http request)`,
  `(scm net http response)`.
