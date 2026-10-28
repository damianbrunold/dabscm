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
Description: Returns the body of the HTTP response: a bytevector if the response was created with one, or received
  with a body that is not text (see http-get), or is a file response (its part of the file); otherwise a
  string. A streamed response (make-http-stream-response) has no body to return: an error.
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

### `http-response-with-headers`

*(no documentation)*

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

### `make-http-file-response`

```
Syntax: (make-http-file-response status headers path [offset [length]])
Library: (scm net http response)
Description: Creates an HTTP response whose body is a part of the file at path: length bytes from
  offset (default: from 0 to the end of the file). tcp-http-serve sends it straight from the file,
  so large files need not fit in memory. The file must exist and the part must lie within it.
  Content-Length is set from the length unless headers give one.
Example:
  (make-http-file-response 200 '(("Content-Type" . "video/mp4")) "/srv/v.mp4")
  (make-http-file-response 206 headers "/srv/v.mp4" 1000 500)
```

### `make-http-response`

```
Syntax: (make-http-response status headers body)
Library: (scm net http response)
Description: Creates an HTTP response object. status is an integer, headers is an alist, body is a string or bytevector.
Example:
  (make-http-response 200 '() "OK")
```

### `make-http-stream-response`

```
Syntax: (make-http-stream-response status headers writer)
Library: (scm net http response)
Description: Creates an HTTP response whose body tcp-http-serve produces by calling (writer port)
  with a binary output port to the client, after sending the status and headers. The body ends
  when writer returns (the connection then closes), so there is no Content-Length; call
  flush-output-port to send what was written so far (server-sent events, progress). Writing
  raises an error once the client has gone.
Example:
  (make-http-stream-response 200 '(("Content-Type" . "text/event-stream"))
    (lambda (port)
      (write-bytevector (string->utf8 "data: hello\n\n") port)
      (flush-output-port port)))
```

### `text-response`

```
Syntax: (text-response body)
Library: (scm net http response)
Description: Creates a 200 OK response with Content-Type text/plain; charset=utf-8.
Example:
  (text-response "hello")
```

