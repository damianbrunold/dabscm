# `(scm net http route)`

HTTP request routing for servers

## Overview

`(scm net http route)` adds request routing on top of the HTTP server: map method
+ path patterns to handlers, capture path parameters, and parse query strings. It
turns a bare request handler into a small web application.

## Common uses

Define routes and run the app:

A handler receives the request and the captured path parameters:

```scheme
(import (scm net http route) (scm net http response))

(get! "/" (lambda (req params) (http-ok "home")))
(get! "/users/:id"
      (lambda (req params)
        (http-ok (string-append "user " (params-ref params "id")))))
(post! "/users" (lambda (req params) (http-ok "created")))

(run-app 8080)
```

Helpers for working with URLs:

```scheme
(url-path "/users/42?limit=10")          ;; => "/users/42"
(parse-query-string "limit=10&page=2")   ;; => (("limit" . "10") ("page" . "2"))
```

For a lower-level explicit router use `make-router`, `router-add!`, and
`router-dispatch`.


## Exports

### `delete!`

```
Syntax: (delete! pattern handler)
Library: (scm net http route)
Description: Registers a DELETE route on the default router.
Example:
  (delete! "/users/:id" (lambda (req params) (http-ok "deleted")))
```

### `get!`

```
Syntax: (get! pattern handler)
Library: (scm net http route)
Description: Registers a GET route on the default router.
Example:
  (get! "/users/:id" (lambda (req params) (http-ok (params-ref params "id"))))
```

### `make-router`

```
Syntax: (make-router)
Library: (scm net http route)
Description: Creates and returns a new router. Use router-add! to register routes
  and router-dispatch to dispatch requests, or run-app-with-router to start a server.
Example:
  (define r (make-router))
  (router-add! r "GET" "/hello/:name" (lambda (req p) (http-ok (params-ref p "name"))))
  (run-app-with-router r 8080)
```

### `params-ref`

```
Syntax: (params-ref params key)
Library: (scm net http route)
Description: Returns the value for key in the path params alist, or #f if not found.
Example:
  (params-ref params "id") => "42"
```

### `parse-query-string`

```
Syntax: (parse-query-string qs)
Library: (scm net http route)
Description: Parses a query string (e.g. "a=1&b=2") into an alist of
  (key . value) string pairs. Percent-encoded characters are not decoded in v1.
  Returns '() for an empty string.
Example:
  (parse-query-string "limit=10&page=2") => (("limit" . "10") ("page" . "2"))
  (parse-query-string "") => ()
```

### `post!`

```
Syntax: (post! pattern handler)
Library: (scm net http route)
Description: Registers a POST route on the default router.
Example:
  (post! "/users" (lambda (req params) (http-ok "created")))
```

### `put!`

```
Syntax: (put! pattern handler)
Library: (scm net http route)
Description: Registers a PUT route on the default router.
Example:
  (put! "/users/:id" (lambda (req params) (http-ok "updated")))
```

### `route!`

```
Syntax: (route! method pattern handler)
Library: (scm net http route)
Description: Registers a route on the module-level default router. method is e.g.
  "GET" (case-insensitive). See router-add! for pattern and handler details.
Example:
  (route! "PATCH" "/items/:id" (lambda (req p) (http-ok "patched")))
```

### `router-add!`

```
Syntax: (router-add! router method pattern handler)
Library: (scm net http route)
Description: Registers a route on router. method is e.g. "GET" (case-insensitive).
  pattern is a path like "/users/:id" where :id captures a segment. * as the
  last segment captures the remaining path. handler is (lambda (req params) ...)
  where params is an alist of captured path parameters.
Example:
  (router-add! r "GET" "/users/:id"
    (lambda (req params)
      (http-ok (params-ref params "id"))))
```

### `router-dispatch`

```
Syntax: (router-dispatch router req)
Library: (scm net http route)
Description: Dispatches an http-request to the first matching route in router.
  Returns an http-response. Returns 404 Not Found if no route matches.
Example:
  (router-dispatch my-router req)
```

### `run-app`

```
Syntax: (run-app port [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])
Library: (scm net http route)
Description: Starts an HTTP server on port using the default router and blocks
  indefinitely. Register routes with get!, post!, put!, delete!, or route! before
  calling run-app. Optional arguments are forwarded to serve-forever / tcp-http-serve;
  see (scm net http server) for details and defaults.
Example:
  (get! "/" (lambda (req p) (http-ok "Hello, world!")))
  (run-app 8080)
  (run-app 8080 16 "127.0.0.1")
```

### `run-app-with-router`

```
Syntax: (run-app-with-router router port [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])
Library: (scm net http route)
Description: Starts an HTTP server on port using the given router and blocks
  indefinitely. Use make-router and router-add! to build the router before calling.
  Optional arguments are forwarded to serve-forever / tcp-http-serve.
Example:
  (define r (make-router))
  (router-add! r "GET" "/" (lambda (req p) (http-ok "hi")))
  (run-app-with-router r 8080)
```

### `start-app`

```
Syntax: (start-app port [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])
Library: (scm net http route)
Description: Like run-app, but returns the server object immediately instead of
  blocking. Use this when you need to install a shutdown hook or otherwise act on
  the server before waiting. Pair with server-wait to block.
Example:
  (get! "/" (lambda (req p) (http-ok "hi")))
  (define s (start-app 8080))
  (server-install-shutdown-hook s)
  (server-wait s)
```

### `start-app-with-router`

```
Syntax: (start-app-with-router router port [max-threads [host [read-timeout-ms [max-body-bytes [graceful-stop-ms]]]]])
Library: (scm net http route)
Description: Like run-app-with-router, but returns the server object immediately
  instead of blocking. Pair with server-wait to block.
Example:
  (define s (start-app-with-router my-router 8080))
  (server-install-shutdown-hook s)
  (server-wait s)
```

### `url-path`

```
Syntax: (url-path url)
Library: (scm net http route)
Description: Returns the path component of a URL string, stripping scheme+host
  and query string. Works with both absolute paths (/foo?q=1) and full URLs.
  Percent-encoded characters are not decoded.
Example:
  (url-path "/users/42?limit=10") => "/users/42"
  (url-path "http://example.com/users/42") => "/users/42"
```

### `url-query-params`

```
Syntax: (url-query-params url)
Library: (scm net http route)
Description: Parses and returns the query parameters of url as an alist of
  (key . value) pairs. Combines url-query-string and parse-query-string.
Example:
  (url-query-params "/search?q=hello&n=5") => (("q" . "hello") ("n" . "5"))
```

### `url-query-string`

```
Syntax: (url-query-string url)
Library: (scm net http route)
Description: Returns the query string portion of url (after '?'), or "" if absent.
Example:
  (url-query-string "/users?limit=10&page=2") => "limit=10&page=2"
  (url-query-string "/users") => ""
```

