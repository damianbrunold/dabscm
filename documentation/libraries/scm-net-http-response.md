# `(scm net http response)`

HTTP response construction and accessors

## Overview

`(scm net http response)` is the HTTP response value type plus a set of
constructors for common status codes. Server handlers return one of these; the
client returns one to you. There are ready-made helpers for typical responses
(`http-ok`, `http-not-found`, …) and content shortcuts (`html-response`,
`json-response`).

## Common uses

Build responses in a handler:

```scheme
(import (scm net http response))

(http-ok "Hello, world!")          ;; 200 with a text body
(http-not-found)                   ;; 404
(json-response '(("ok" . #t)))     ;; JSON body + Content-Type
(http-redirect "/login")           ;; 302 to a new location
```

Inspect a response (e.g. one returned by the client):

```scheme
(http-response-status resp)              ;; => 200
(http-response-header resp "Content-Type")
(http-response-body resp)
```


## Exports

### `html-response`

```
Syntax: (html-response body)
Library: (scm net http response)
Description: Creates a 200 OK response with Content-Type text/html; charset=utf-8.
Example:
  (html-response "<h1>hi</h1>")
```

### `http-bad-request`

```
Syntax: (http-bad-request msg)
Library: (scm net http response)
Description: Creates a 400 Bad Request HTTP response with msg as the body.
Example:
  (http-bad-request "Missing field")
```

### `http-forbidden`

```
Syntax: (http-forbidden [msg])
Library: (scm net http response)
Description: Creates a 403 Forbidden HTTP response. msg defaults to "Forbidden".
Example:
  (http-forbidden)
  (http-forbidden "Admin only")
```

### `http-internal-error`

```
Syntax: (http-internal-error msg)
Library: (scm net http response)
Description: Creates a 500 Internal Server Error HTTP response with msg as the body.
Example:
  (http-internal-error "Unexpected error")
```

### `http-not-found`

```
Syntax: (http-not-found)
Library: (scm net http response)
Description: Creates a 404 Not Found HTTP response.
Example:
  (http-not-found)
```

### `http-ok`

```
Syntax: (http-ok body)
Library: (scm net http response)
Description: Creates a 200 OK HTTP response with the given body string.
Example:
  (http-ok "Hello, world!")
```

### `http-permanent-redirect`

```
Syntax: (http-permanent-redirect location)
Library: (scm net http response)
Description: Creates a 301 Moved Permanently HTTP response with the given Location header.
Example:
  (http-permanent-redirect "https://example.com/new")
```

### `http-redirect`

```
Syntax: (http-redirect location)
Library: (scm net http response)
Description: Creates a 302 Found HTTP response with the given Location header.
  Use for temporary redirects from GET requests.
Example:
  (http-redirect "/login")
```

### `http-response-body`

```
Syntax: (http-response-body response)
Library: (scm net http response)
Description: Returns the body of the HTTP response. If the response was created with a bytevector body, returns a bytevector; otherwise returns a string.
Example:
  (http-response-body resp) => "Hello, world!"
```

### `http-response-header`

```
Syntax: (http-response-header resp name)
Library: (scm net http response)
Description: Returns the value of the named header in resp, or #f if not present.
  Header name comparison is case-insensitive.
Example:
  (http-response-header resp "Content-Type") => "text/html"
```

### `http-response-headers`

```
Syntax: (http-response-headers response)
Library: (scm net http response)
Description: Returns the headers of the HTTP response as an alist of (name . value) pairs.
Example:
  (http-response-headers resp) => (("Content-Type" . "text/html"))
```

### `http-response-status`

```
Syntax: (http-response-status response)
Library: (scm net http response)
Description: Returns the HTTP status code of the response as an integer.
Example:
  (http-response-status resp) => 200
```

### `http-response?`

```
Syntax: (http-response? x)
Library: (scm net http response)
Description: Returns #t if x is an HTTP response object.
Example:
  (http-response? (make-http-response 200 '() "ok")) => #t
```

### `http-see-other`

```
Syntax: (http-see-other location)
Library: (scm net http response)
Description: Creates a 303 See Other HTTP response with the given Location header.
  Use after a successful POST to redirect to a GET (POST/Redirect/GET pattern).
Example:
  (http-see-other "/items/42")
```

### `http-unauthorized`

```
Syntax: (http-unauthorized [msg])
Library: (scm net http response)
Description: Creates a 401 Unauthorized HTTP response. msg defaults to "Unauthorized".
Example:
  (http-unauthorized)
```

### `json-response`

```
Syntax: (json-response body)
Library: (scm net http response)
Description: Creates a 200 OK response with Content-Type application/json; charset=utf-8.
  body should already be a JSON-encoded string.
Example:
  (json-response "{\"ok\":true}")
```

### `make-http-response`

```
Syntax: (make-http-response status headers body)
Library: (scm net http response)
Description: Creates an HTTP response object. status is an integer, headers is an alist, body is a string or bytevector.
Example:
  (make-http-response 200 '() "OK")
```

### `text-response`

```
Syntax: (text-response body)
Library: (scm net http response)
Description: Creates a 200 OK response with Content-Type text/plain; charset=utf-8.
Example:
  (text-response "hello")
```

