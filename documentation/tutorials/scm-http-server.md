---
title: (scm net http server) and (scm net http route): web servers
part: libraries
order: 1025
libraries: (scm net http server) (scm net http route) (scm net http request) (scm net http response)
summary: Handlers as procedures from request to response, response helpers, routing with path parameters, wildcards and query strings, a JSON API with shared state, running and stopping a server, streamed responses, going to production.
---
# (scm net http server) and (scm net http route): web servers

| library | does |
|---|---|
| `(scm net http request)` | the request value: method, URL, headers, body |
| `(scm net http response)` | the response value and helpers such as `http-ok` |
| `(scm net http route)` | maps method and path to handlers |
| `(scm net http server)` | accepts connections and runs the handlers |

Sessions, forms, static files and middleware are in
[web applications](scm-web-app.md); the client side is in
[HTTP client](scm-http-client.md).

```scheme
(import (scheme base) (scheme write) (srfi 18) (scm json simple)
        (scm net http request) (scm net http response) (scm net http route)
        (scm net http server) (scm net http client))
```

## A handler is a procedure

A handler takes a request and returns a response. Nothing else is needed
to write one, and it can be tried out without a server by making the
request by hand:

```scheme
(define (hello req)
  (text-response (string-append "You asked for " (http-request-url req))))

(define resp (hello (make-http-request "GET" "/tea?strong=yes" '() #f)))
(http-response-status resp)                 ;; => 200
(http-response-body resp)                   ;; => "You asked for /tea?strong=yes"
(http-response-header resp "Content-Type")  ;; => "text/plain; charset=utf-8"
```

`make-http-request` takes the method, the URL, the headers as an alist and
the body (`#f` for none). A server hands its handler the path and query as
the URL, as above.

## Responses

| helper | status |
|---|---|
| `http-ok`, `text-response`, `html-response`, `json-response` | 200 |
| `http-see-other` (after a POST), `http-redirect`, `http-permanent-redirect` | 303, 302, 301 |
| `http-bad-request`, `http-unauthorized`, `http-forbidden`, `http-not-found` | 400, 401, 403, 404 |
| `http-internal-error` | 500 |

`make-http-response` makes any other one from a status, headers and a body
(string or bytevector):

```scheme
(http-response-status (http-not-found))     ;; => 404
(http-response-header (http-see-other "/teas/7") "Location") ;; => "/teas/7"

(define created
  (make-http-response 201 '(("Content-Type" . "application/json") ("Location" . "/teas/4"))
                      "{\"id\":4}"))
(http-response-status created)              ;; => 201
```

## Routing

A router picks the handler by method and path. Route handlers get a second
argument, the parameters captured by `:name` segments:

```scheme
(define r (make-router))
(router-add! r "GET" "/" (lambda (req params) (text-response "Teashop")))
(router-add! r "GET" "/teas/:name"
             (lambda (req params) (text-response (string-append "About " (params-ref params "name")))))
(router-add! r "GET" "/files/*"
             (lambda (req params) (text-response (params-ref params "*"))))

(define (get path) (router-dispatch r (make-http-request "GET" path '() #f)))

(http-response-body (get "/teas/Sencha"))   ;; => "About Sencha"
(http-response-body (get "/teas/Gyokuro%20Imperial")) ;; => "About Gyokuro Imperial"
(http-response-body (get "/files/2025/menu.pdf")) ;; => "2025/menu.pdf"
(http-response-status (get "/coffee"))      ;; => 404
```

`:name` matches one segment and is percent-decoded; `*` at the end takes
the rest of the path as it is. A path that exists under another method
gets 405 Method Not Allowed and an `Allow` header, as HTTP asks:

```scheme
(define del (router-dispatch r (make-http-request "DELETE" "/teas/Sencha" '() #f)))
(http-response-status del)                  ;; => 405
(http-response-header del "Allow")          ;; => "GET, HEAD"
```

Query strings are not part of the route; read them from the URL:

```scheme
(url-path "/teas?origin=Japan&max=10")      ;; => "/teas"
(url-query-params "/teas?origin=Japan&max=10") ;; => (("origin" . "Japan") ("max" . "10"))
```

## Example: a JSON API

A small API for a tea shop's catalogue: list (filtered by origin), show,
add, remove. The server runs handlers on several threads at once, so the
shared catalogue is changed only under a mutex:

```scheme
(define teas '())                           ; list of JSON objects (alists)
(define next-id 1)
(define lock (make-mutex))

(define (locked thunk)
  (dynamic-wind (lambda () (mutex-lock! lock)) thunk (lambda () (mutex-unlock! lock))))

(define (json status data)
  (make-http-response status '(("Content-Type" . "application/json; charset=utf-8"))
                      (json->string data)))

(define (find-tea id)
  (let loop ((ts teas))
    (cond ((null? ts) #f)
          ((equal? (json-ref (car ts) "id") id) (car ts))
          (else (loop (cdr ts))))))

(define (list-teas req params)
  (let* ((origin (assoc "origin" (url-query-params (http-request-url req))))
         (wanted (if origin
                     (filter-list (lambda (t) (equal? (json-ref t "origin") (cdr origin))) teas)
                     teas)))
    (json 200 (list->vector (reverse wanted)))))

(define (filter-list keep? xs)
  (cond ((null? xs) '())
        ((keep? (car xs)) (cons (car xs) (filter-list keep? (cdr xs))))
        (else (filter-list keep? (cdr xs)))))

(define (show-tea req params)
  (let ((tea (locked (lambda () (find-tea (string->number (params-ref params "id")))))))
    (if tea
        (json 200 tea)
        (json 404 '(("error" . "no such tea"))))))

(define (add-tea req params)
  (let ((data (guard (e (#t #f)) (json-parse (or (http-request-body req) "")))))
    (if (not (and (pair? data) (string? (json-ref data "name" #f))))
        (json 400 '(("error" . "a tea needs a name")))
        (locked
         (lambda ()
           (let ((tea `(("id" . ,next-id)
                        ("name" . ,(json-ref data "name"))
                        ("origin" . ,(json-ref data "origin" "unknown")))))
             (set! teas (cons tea teas))
             (set! next-id (+ next-id 1))
             (make-http-response 201
               `(("Content-Type" . "application/json; charset=utf-8")
                 ("Location" . ,(string-append "/teas/" (number->string (json-ref tea "id")))))
               (json->string tea))))))))

(define (remove-tea req params)
  (let ((id (string->number (params-ref params "id"))))
    (locked (lambda ()
              (set! teas (filter-list (lambda (t) (not (equal? (json-ref t "id") id))) teas))))
    (make-http-response 204 '() "")))

(define api (make-router))
(router-add! api "GET" "/teas" list-teas)
(router-add! api "GET" "/teas/:id" show-tea)
(router-add! api "POST" "/teas" add-tea)
(router-add! api "DELETE" "/teas/:id" remove-tea)
```

The handlers are plain procedures, so the API can be checked without a
network:

```scheme
(define (call method url body)
  (router-dispatch api (make-http-request method url '() body)))

(http-response-status (call "POST" "/teas" "{\"name\": \"Sencha\", \"origin\": \"Japan\"}")) ;; => 201
(http-response-status (call "POST" "/teas" "{\"origin\": \"Kenya\"}")) ;; => 400
(http-response-body (call "GET" "/teas/1" #f)) ;; => "{\"id\":1,\"name\":\"Sencha\",\"origin\":\"Japan\"}"
(http-response-status (call "GET" "/teas/99" #f)) ;; => 404
```

## Running the server

`start-app-with-router` starts a server on a port and returns at once;
`server-stop` stops it. Here the server listens on the loopback address
only, and the HTTP client talks to it:

```scheme
(define server (start-app-with-router api 18901 8 "127.0.0.1"))
(define base "http://127.0.0.1:18901")

(define added (http-post-json (string-append base "/teas") "{\"name\": \"Assam\", \"origin\": \"India\"}"))
(http-response-status added)                ;; => 201
(http-response-header added "Location")     ;; => "/teas/2"

(http-post-json (string-append base "/teas") "{\"name\": \"Gyokuro\", \"origin\": \"Japan\"}")
(define japan (http-get (string-append base "/teas?origin=Japan")))
(map (lambda (t) (json-ref t "name")) (vector->list (json-parse (http-response-body japan))))
;; => ("Sencha" "Gyokuro")

(http-response-status (http-delete (string-append base "/teas/1"))) ;; => 204
(vector-length (json-parse (http-response-body (http-get (string-append base "/teas"))))) ;; => 2
```

The arguments after the port are the number of worker threads and the
address to listen on; leave the address out (`"0.0.0.0"`) to accept
connections from other machines.

## Streamed responses

A response body need not exist up front. `make-http-stream-response` calls
a procedure with a port to the client, for long downloads produced on the
fly or server-sent events:

```scheme
(define (countdown req params)
  (make-http-stream-response 200 '(("Content-Type" . "text/plain; charset=utf-8"))
    (lambda (port)
      (for-each (lambda (n)
                  (write-bytevector (string->utf8 (string-append (number->string n) "\n")) port)
                  (flush-output-port port))
                '(3 2 1)))))
(router-add! api "GET" "/countdown" countdown)

(http-response-body (http-get (string-append base "/countdown"))) ;; => "3\n2\n1\n"
(server-stop server)                        ;; => #t
```

Routes can be added while the server runs, as here. `make-http-file-response`
sends a file from disk without reading it into memory; `file-response` in
`(scm net http static)` adds caching and byte ranges to it.

## In production

A server program starts the server and then waits for it. With
`server-install-shutdown-hook`, Ctrl-C or `systemctl stop` lets running
requests finish before the program ends:

```scheme no-test
(define server (start-app-with-router api 8080 32 "127.0.0.1"))
(server-install-shutdown-hook server)
(server-wait server)
```

- `run-app-with-router` does all three in one call; `serve-forever` takes a
  bare handler instead of a router.
- `get!`, `post!`, `put!`, `delete!` and `run-app` use one built-in router,
  which suits a single-file script.
- Behind a reverse proxy (nginx, Caddy) listen on `127.0.0.1` and let the
  proxy handle TLS.
- `tcp-http-serve` takes all the limits: read timeout, maximum body size
  (4 MB by default, larger uploads get 413), when large bodies are spooled
  to a temporary file, and how many connections may wait for a thread.

`(scm net http route)`'s `delete!` has the same name as SRFI 1's: import
one of them with `except` or `prefix` when a program uses both.

## Where next

- [Web applications](scm-web-app.md): forms, sessions, logins, static
  files, uploads, error pages and security headers.
- [HTTP client](scm-http-client.md), [WebSockets](scm-websocket.md),
  [JSON](scm-json.md), [HTML](scm-html.md) for pages.
- `scm new-app` creates a complete web application to start from:
  [scaffold](scm-scaffold.md).
- Reference: `(scm net http server)`, `(scm net http route)`,
  `(scm net http request)`, `(scm net http response)`.
