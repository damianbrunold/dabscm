# `(scm net http request)`

HTTP request construction and accessors

## Exports

### `http-request-body`

```
Syntax: (http-request-body request)
Library: (scm net http request)
Description: Returns the body of the HTTP request as a string, or #f if there is no body.
Example:
  (http-request-body req) => "hello"
```

### `http-request-body-bytes`

```
Syntax: (http-request-body-bytes request)
Library: (scm net http request)
Description: Returns the body of the HTTP request as a bytevector, or #f if there is no body. Unlike http-request-body which decodes the body as UTF-8 text, this preserves the raw bytes and is the correct accessor for binary uploads.
Example:
  (http-request-body-bytes req) => #u8(72 101 108 108 111)
```

### `http-request-header`

```
Syntax: (http-request-header req name)
Library: (scm net http request)
Description: Returns the value of the named header in req, or #f if not present.
  Header name comparison is case-insensitive.
Example:
  (http-request-header req "Host") => "example.com"
```

### `http-request-headers`

```
Syntax: (http-request-headers request)
Library: (scm net http request)
Description: Returns the headers of the HTTP request as an alist of (name . value) pairs.
Example:
  (http-request-headers req) => (("Host" . "example.com"))
```

### `http-request-method`

```
Syntax: (http-request-method request)
Library: (scm net http request)
Description: Returns the HTTP method of the request as a string.
Example:
  (http-request-method req) => "GET"
```

### `http-request-url`

```
Syntax: (http-request-url request)
Library: (scm net http request)
Description: Returns the URL of the HTTP request as a string.
Example:
  (http-request-url req) => "/api/users"
```

### `http-request?`

```
Syntax: (http-request? x)
Library: (scm net http request)
Description: Returns #t if x is an HTTP request object.
Example:
  (http-request? (make-http-request "GET" "/" '() #f)) => #t
```

### `make-http-request`

```
Syntax: (make-http-request method url headers body)
Library: (scm net http request)
Description: Creates an HTTP request object. headers is an alist of (name . value) pairs. body is a string or #f.
Example:
  (make-http-request "GET" "/" '() #f)
```

