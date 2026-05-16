# `(scm net http response)`

HTTP response construction and accessors

## Exports

### `http-bad-request`

```
Syntax: (http-bad-request msg)
Library: (scm net http response)
Description: Creates a 400 Bad Request HTTP response with msg as the body.
Example:
  (http-bad-request "Missing field")
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

### `make-http-response`

```
Syntax: (make-http-response status headers body)
Library: (scm net http response)
Description: Creates an HTTP response object. status is an integer, headers is an alist, body is a string or bytevector.
Example:
  (make-http-response 200 '() "OK")
```

